#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'postflight'

class PostflightTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def setup
    opts = { no_progress: true,
             feed_validate_script: 'test/bin/fake_feed_validate.pl' }
    @config = Config.new opts
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    shipment = TestShipment.new(test_name)
    stage = Postflight.new(shipment, @config)
    refute_nil stage, 'stage successfully created'
  end

  def test_run
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 T contone 2')
    stage = Preflight.new(shipment, @config)
    stage.run
    stage = Postflight.new(shipment, @config)
    stage.run
    puts stage.errors
    assert_equal 0, stage.errors.count, 'stage runs without errors'
  end

  def test_metadata_mismatch_removed
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 BC T bitonal 1')
    stage = Preflight.new(shipment, @config)
    stage.run
    FileUtils.rm_r(File.join(shipment.directory, shipment.barcodes[0]),
                   force: true)
    stage = Postflight.new(shipment, @config)
    stage.run
    assert stage.errors.any? { |e| /removed/.match? e.to_s },
           'stage gripes about removed barcode'
  end

  def test_metadata_mismatch_added
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 BC T bitonal 1')
    stage = Preflight.new(shipment, @config)
    stage.run
    Dir.mkdir File.join(shipment.directory, TestShipment.generate_barcode)
    stage = Postflight.new(shipment, @config)
    stage.run
    assert stage.errors.any? { |e| /added/i.match? e.to_s },
           'stage gripes about added barcode'
  end

  def test_feed_validate_error # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 T contone 2')
    stage = Preflight.new(shipment, @config)
    stage.run
    ENV['FAKE_FEED_VALIDATE_FAIL'] = File.join(shipment.barcodes[0],
                                               '00000001.tif')
    stage = Postflight.new(shipment, @config)
    stage.run
    assert stage.errors.any? { |e| /missing field value/i.match? e.to_s },
           'error(s) from feed validate'
    assert stage.warnings.any? { |e| /validation failed/i.match? e.to_s },
           'warning(s) from feed validate'
    assert stage.errors.none? { |e| /failure!/i.match? e.to_s },
           'no "failure!" error from feed validate'
    ENV.delete 'FAKE_FEED_VALIDATE_FAIL'
  end

  def test_new_feed_validate_error # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 T contone 2')
    stage = Preflight.new(shipment, @config)
    stage.run
    ENV['FAKE_NEW_FEED_VALIDATE_FAIL'] = File.join(shipment.barcodes[0],
                                                   '00000001.tif')
    stage = Postflight.new(shipment, @config)
    stage.run
    assert stage.errors.any? { |e| /missing field value/i.match? e.to_s },
           'error(s) from feed validate'
    assert stage.warnings.any? { |e| /validation failed/i.match? e.to_s },
           'warning(s) from feed validate'
    assert stage.errors.none? { |e| /failure!/i.match? e.to_s },
           'no "failure!" error from feed validate'
    ENV.delete 'FAKE_NEW_FEED_VALIDATE_FAIL'
  end

  def test_feed_validate_crash
    ENV['FAKE_FEED_VALIDATE_CRASH'] = '1'
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 T contone 2')
    stage = Preflight.new(shipment, @config)
    stage.run
    stage = Postflight.new(shipment, @config)
    stage.run
    assert(stage.errors.any? { |e| /returned 1/i.match? e.to_s },
           'nonzero feed validate exit status')
    ENV.delete 'FAKE_FEED_VALIDATE_CRASH'
  end

  def test_checksum_mismatch
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 T contone 2')
    stage = Preflight.new(shipment, @config)
    stage.run
    file = File.join(shipment.directory, 'source', shipment.barcodes[0],
                     '00000001.tif')
    `echo 'test' > #{file}`
    stage = Postflight.new(shipment, @config)
    stage.run
    assert stage.errors.any? { |e| /SHA mismatch/i.match? e.to_s },
           'checksum error generated'
  end

  def test_file_missing
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 T contone 2')
    stage = Preflight.new(shipment, @config)
    stage.run
    file = File.join(shipment.directory, 'source', shipment.barcodes[0],
                     '00000001.tif')
    FileUtils.rm file
    stage = Postflight.new(shipment, @config)
    stage.run
    assert stage.errors.any? { |e| /file missing/i.match? e.to_s },
           'file missing error generated'
  end

  def test_file_added
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 T contone 2')
    stage = Preflight.new(shipment, @config)
    stage.run
    file = File.join(shipment.directory, 'source', shipment.barcodes[0],
                     '00000003.tif')
    `echo 'test' > #{file}`
    stage = Postflight.new(shipment, @config)
    stage.run
    assert stage.errors.any? { |e| /SHA missing/i.match? e.to_s },
           'SHA missing error generated'
  end
end
