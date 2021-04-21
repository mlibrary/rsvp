#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'processor'

class ProcessorTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment = TestShipment.new(test_name)
    processor = Processor.new(shipment.directory, {})
    refute_nil processor, 'processor successfully created'
    refute_nil processor.status, 'processor status exists'
    refute File.exist?(File.join(shipment.directory, 'status.json')),
           'status.json not created yet'
    processor.write_status
    assert File.exist?(File.join(shipment.directory, 'status.json')),
           'status.json created'
    metadata = processor.status[:metadata]
    assert metadata, 'processor metadata initialized'
  end

  def test_config
    shipment = TestShipment.new(test_name)
    options = { config_dir: File.join(TEST_ROOT, 'config') }
    processor = Processor.new(shipment.directory, options)
    refute_nil processor, 'processor successfully created'
    assert_match(/fake_feed_validate/, processor.config[:feed_validate_script],
                 'has custom feed validate path')
  end

  def test_unlink_status_on_reset
    shipment = TestShipment.new(test_name)
    status_json = File.join(shipment.directory, 'status.json')
    FileUtils.touch(status_json)
    options = { restart_all: 1 }
    Processor.new(shipment.directory, options)
    refute File.exist?(status_json), 'status.json deleted on reset'
  end

  def test_stages
    shipment = TestShipment.new(test_name)
    processor = Processor.new(shipment.directory)
    assert_kind_of Array, processor.stages, 'processor#stages is Array'
  end

  def test_query
    shipment = TestShipment.new(test_name)
    processor = Processor.new(shipment.directory)
    assert_output(/not.yet.run/i) { processor.query }
  end

  def test_run # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment = TestShipment.new(test_name, 'BC F .DS_Store')
    options = { no_progress: true }
    processor = Processor.new(shipment.directory, options)
    capture_io do
      processor.run
    end
    assert_kind_of Hash, processor.status
    refute_nil processor.status[:stages]
    stage = processor.status[:stages][:Preflight]
    refute_nil stage
    refute_nil stage[:start]
    refute_nil stage[:end]
    assert stage[:errors].any? { |e| /no.TIFF/i.match? e.to_s },
           'Preflight fails with no TIFFs error'
    assert stage[:warnings].any? { |e| /\.DS_Store/.match? e.to_s },
           'Preflight warns about .DS_Store'
  end

  def test_invalid_status_file
    shipment = TestShipment.new(test_name, 'BC F .DS_Store')
    status_json = File.join(shipment.directory, 'status.json')
    FileUtils.touch(status_json)
    assert_raises(JSON::ParserError) { Processor.new(shipment.directory, {}) }
    assert_equal(File.size(status_json), 0, 'status.json is unmodified')
  end

  def test_discard_failure
    spec = 'BC T bad_16bps 1'
    shipment = TestShipment.new(test_name, spec)
    processor = Processor.new(shipment.directory, {})
    capture_io do
      processor.run
    end
    keys_before = processor.status[:stages].keys.count
    processor.send :discard_failure
    keys_after = processor.status[:stages].keys.count
    assert(keys_after < keys_before, 'discard_failure removes failing stage')
  end

  def test_reload_status_file # rubocop:disable Metrics/MethodLength
    spec = 'BC T bad_16bps 1'
    shipment = TestShipment.new(test_name, spec)
    processor = Processor.new(shipment.directory, {})
    capture_io do
      processor.run
    end
    processor.write_status
    processor = Processor.new(shipment.directory, {})
    tiff_validator_status = processor.status[:stages][:'TIFF Validator']
    assert_kind_of Error, tiff_validator_status[:errors][0],
                   'Error class reconstituted from status.json'
  end

  def test_abort_on_error
    spec = 'BC T bad_16bps 1'
    shipment = TestShipment.new(test_name, spec)
    processor = Processor.new(shipment.directory, {})
    capture_io do
      processor.run
    end
    assert_output(/aborting/i) do
      processor.run
    end
  end

  def test_error_query
    spec = 'BC T bad_16bps 1'
    shipment = TestShipment.new(test_name, spec)
    processor = Processor.new(shipment.directory, {})
    capture_io do
      processor.run
    end
    eq = processor.error_query
    assert eq.is_a?(Hash), 'error_query returns a Hash'
    assert eq.key?(shipment.barcodes[0]), 'error_query has barcode key'
  end

  def test_warning_query # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    spec = 'BC T contone 1'
    shipment = TestShipment.new(test_name, spec)
    ds_store = File.join(shipment.directory, shipment.barcodes[0], '.DS_Store')
    FileUtils.touch(ds_store)
    processor = Processor.new(shipment.directory, {})
    capture_io do
      processor.run
    end
    wq = processor.warning_query
    assert wq.is_a?(Hash), 'warning_query returns a Hash'
    assert wq.key?(shipment.barcodes[0]), 'warning_query has barcode key'
  end

  def test_metadata_query_no_source
    spec = 'BC T contone 1'
    shipment = TestShipment.new(test_name, spec)
    processor = Processor.new(shipment.directory, {})
    assert_match(/not\syet\spopulated/, processor.metadata_query,
                 'metadata_query indicates no source directory')
  end

  def test_metadata_query # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    spec = 'BC T contone 1-2'
    shipment = TestShipment.new(test_name, spec)
    processor = Processor.new(shipment.directory, {})
    capture_io do
      processor.run
    end
    tiff = File.join(shipment.source_directory, shipment.barcodes[0],
                     '00000001.tif')
    `echo 'test' >> #{tiff}`
    tiff = File.join(shipment.source_directory, shipment.barcodes[0],
                     '00000002.tif')
    FileUtils.rm tiff
    tiff = File.join(shipment.source_directory, shipment.barcodes[0],
                     '00000003.tif')
    FileUtils.touch tiff
    mq = processor.metadata_query
    assert_match(/1\schanged/, mq, 'metadata_query notes changed source file')
    assert_match(/1\sadded/, mq, 'metadata_query notes added source file')
    assert_match(/1\sremoved/, mq, 'metadata_query notes removed source file')
  end
end
