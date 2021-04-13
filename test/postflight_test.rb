#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'postflight'

class PostflightTest < Minitest::Test
  def setup
    @options = { no_progress: true }
    @options[:config] = { feed_validate_script:
                          'test/bin/fake_feed_validate.pl' }
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    shipment = TestShipment.new(test_name)
    stage = Postflight.new(shipment, {}, @options)
    refute_nil stage, 'stage successfully created'
  end

  def test_run
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 T contone 2')
    metadata = { barcodes: shipment.barcodes.clone }
    stage = Preflight.new(shipment, metadata, @options)
    stage.run
    stage = Postflight.new(shipment, metadata, @options)
    stage.run
    assert_equal 0, stage.errors.count, 'stage runs without errors'
  end

  def test_metadata_mismatch_removed
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 BC T bitonal 1')
    metadata = {}
    stage = Preflight.new(shipment, metadata, @options)
    stage.run
    metadata[:barcodes] << TestShipment.generate_barcode
    stage = Postflight.new(shipment, metadata, @options)
    stage.run
    assert stage.errors.any?(/removed/), 'stage gripes about removed barcode'
  end

  def test_metadata_mismatch_added
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 BC T bitonal 1')
    metadata = {}
    stage = Preflight.new(shipment, metadata, @options)
    stage.run
    metadata[:barcodes].pop
    stage = Postflight.new(shipment, metadata, @options)
    stage.run
    assert stage.errors.any?(/added/), 'stage gripes about added barcode'
  end

  def test_feed_validate_error
    ENV['FAKE_FEED_VALIDATE_FAIL'] = '1'
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 T contone 2')
    metadata = { barcodes: shipment.barcodes.clone }
    stage = Preflight.new(shipment, metadata, @options)
    stage.run
    stage = Postflight.new(shipment, metadata, @options)
    stage.run
    assert stage.errors.any?(/something\swent\swrong/),
           'error(s) from feed validate'
    ENV.delete 'FAKE_FEED_VALIDATE_FAIL'
  end

  def test_checksum_mismatch
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 T contone 2')
    metadata = {}
    stage = Preflight.new(shipment, metadata, @options)
    stage.run
    file = File.join(shipment.directory, 'source', shipment.barcodes[0],
                     '00000001.tif')
    `echo 'test' > #{file}`
    stage = Postflight.new(shipment, metadata, @options)
    stage.run
    assert stage.errors.any?(/checksum\smismatch/), 'checksum error generated'
  end

  def test_file_missing
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 T contone 2')
    metadata = {}
    stage = Preflight.new(shipment, metadata, @options)
    stage.run
    file = File.join(shipment.directory, 'source', shipment.barcodes[0],
                     '00000001.tif')
    FileUtils.rm file
    stage = Postflight.new(shipment, metadata, @options)
    stage.run
    assert stage.errors.any?(/file\smissing/), 'file missing error generated'
  end

  def test_file_added
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 T contone 2')
    metadata = {}
    stage = Preflight.new(shipment, metadata, @options)
    stage.run
    file = File.join(shipment.directory, 'source', shipment.barcodes[0],
                     '00000003.tif')
    `echo 'test' > #{file}`
    stage = Postflight.new(shipment, metadata, @options)
    stage.run
    assert stage.errors.any?(/file\sadded/), 'file added error generated'
  end
end
