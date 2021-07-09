#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'processor'
require 'fixtures'

class ProcessorTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def setup
    @options = { config_dir: File.join(TEST_ROOT, 'config') }
    # For testing under Docker, fall back to ImageMagick instead of Kakadu
    ENV['KAKADONT'] = '1'
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    shipment = TestShipment.new(test_name)
    processor = Processor.new(shipment)
    refute_nil processor, 'processor successfully created'
    refute File.exist?(File.join(shipment.directory, 'status.json')),
           'status.json not created yet'
    processor.write_status_file
    assert File.exist?(File.join(shipment.directory, 'status.json')),
           'status.json created'
  end

  def test_config
    shipment = TestShipment.new(test_name)
    processor = Processor.new(shipment, @options)
    refute_nil processor, 'processor successfully created'
    assert_match(/fake_feed_validate/, processor.config[:feed_validate_script],
                 'has custom feed validate path')
  end

  def test_unlink_status_on_restart
    shipment = TestShipment.new(test_name)
    status_json = File.join(shipment.directory, 'status.json')
    FileUtils.touch(status_json)
    options = { restart_all: 1 }
    Processor.new(shipment.directory, options)
    refute File.exist?(status_json), 'status.json deleted on reset'
  end

  def test_stages
    shipment = TestShipment.new(test_name)
    processor = Processor.new(shipment)
    assert_kind_of Array, processor.stages, 'processor#stages is Array'
    assert_kind_of Stage, processor.stages[0],
                   'processor#stages is Array of Stage'
  end

  def test_run # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment = TestShipment.new(test_name, 'BC F .DS_Store')
    options = { no_progress: true }
    processor = Processor.new(shipment, options)
    capture_io do
      processor.run
    end
    errs = processor.errors['Preflight'][shipment.barcodes[0]]
    warnings = processor.warnings['Preflight'][shipment.barcodes[0]]
    assert errs.any? { |e| /no.TIFF/i.match? e.to_s },
           'Preflight fails with no TIFFs error'
    assert warnings.any? { |e| /\.DS_Store/.match? e.to_s },
           'Preflight warns about .DS_Store'
  end

  def test_invalid_status_file
    shipment = TestShipment.new(test_name, 'BC F .DS_Store')
    status_json = File.join(shipment.directory, 'status.json')
    FileUtils.touch(status_json)
    assert_raises(JSON::ParserError) { Processor.new(shipment.directory, {}) }
    assert_equal(File.size(status_json), 0, 'status.json is unmodified')
  end

  # Don't pass TestShipment to anything we want to serialize --
  # the initializer isn't JSON-aware
  def test_reload_status_file
    shipment = TestShipment.new(test_name, 'BC T bad_16bps 1')
    processor = Processor.new(shipment.directory)
    capture_io do
      processor.run
    end
    processor.write_status_file
    processor = Processor.new(shipment.directory, {})
    errs = processor.errors['TIFF Validator'][shipment.barcodes[0]]
    assert_kind_of Error, errs[0], 'Error class reconstituted from status.json'
  end

  # Don't pass TestShipment to anything we want to serialize --
  # the initializer isn't JSON-aware
  def test_move_status_file # rubocop:disable Metrics/AbcSize
    shipment = TestShipment.new(test_name, 'BC')
    processor = Processor.new(shipment.directory)
    processor.write_status_file
    shipment_copy_dir = File.join(TestShipment::PATH, test_name + '_COPY')
    FileUtils.copy_entry(shipment.directory, shipment_copy_dir)
    FileUtils.rm_r(shipment.directory, force: true)
    processor = Processor.new(shipment_copy_dir)
    assert_equal 1, processor.shipment.barcodes.count,
                 'relocated shipment can access its barcodes'
    FileUtils.rm_r(shipment_copy_dir, force: true)
  end

  def test_restore_from_source_directory # rubocop:disable Metrics/MethodLength
    shipment = TestShipment.new(test_name, 'BC T contone 1')
    processor = Processor.new(shipment, {})
    capture_io do
      processor.run
    end
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    # TIFF has been converted into JP2
    refute File.exist?(tiff), '00000001.tif no longer exists'
    capture_io do
      processor.restore_from_source_directory
    end
    assert File.exist?(tiff), '00000001.tif restored from source'
  end

  def test_finalize # rubocop:disable Metrics/MethodLength
    shipment = TestShipment.new(test_name, 'BC T contone 1')
    processor = Processor.new(shipment, @options)
    capture_io do
      processor.run
    end
    processor.write_status_file
    capture_io do
      processor.finalize
    end
    refute File.exist?(processor.status_file), 'status.json deleted'
    refute File.exist?(shipment.source_directory), 'shipment source deleted'
  end

  def test_finalize_does_nothing # rubocop:disable Metrics/MethodLength
    shipment = TestShipment.new(test_name, 'BC T bad_16bps 1')
    processor = Processor.new(shipment, @options)
    capture_io do
      processor.run
    end
    processor.write_status_file
    capture_io do
      processor.finalize
    end
    assert File.exist?(processor.status_file), 'status.json left intact'
    assert File.exist?(shipment.source_directory), 'shipment source left intact'
  end
end

class ProcessorErrorCorrectionTest < Minitest::Test
  def setup
    @options = { config_dir: File.join(TEST_ROOT, 'config') }
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  # Initial run detects bogus file, replacement allows second run to pass,
  # and fixity is updated with the new file.
  def test_error_correction # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    spec = 'BC T contone 1 BC T bad_16bps 1'
    shipment = TestShipment.new(test_name, spec)
    processor = Processor.new(shipment, @options)
    capture_io do
      processor.run
    end
    refute processor.errors.none?, 'error detected'
    bad_barcode = shipment.ordered_barcodes[1]
    tiff = File.join(bad_barcode, '00000001.tif')
    old_checksum = shipment.checksums[tiff]
    fixture = Fixtures.tiff_fixture('contone')
    dest = File.join(shipment.source_barcode_directory(bad_barcode),
                     '00000001.tif')
    FileUtils.cp fixture, dest
    capture_io do
      processor.run
    end
    new_checksum = shipment.checksums[tiff]
    refute_nil new_checksum, 'bad file has a checksum'
    refute_equal new_checksum, old_checksum,
                 'old and new checksums should not match'
  end
end
