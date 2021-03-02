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
    stage = Postflight.new(File.join(TestShipment::PATH, test_name), {},
                           @options)
    refute_nil stage, 'stage successfully created'
  end

  def test_run
    spec = 'BC T bitonal 1 T contone 2'
    shipment = TestShipment.new(test_name, spec)
    metadata = { barcodes: shipment.barcodes.clone }
    stage = Postflight.new(shipment.dir, metadata, @options)
    stage.run
    assert_equal 0, stage.errors.count, 'stage runs without errors'
  end

  def test_metadata_mismatch_removed
    spec = 'BC T bitonal 1 BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    metadata = { barcodes: shipment.barcodes.clone }
    metadata[:barcodes] << TestShipment.generate_barcode
    stage = Postflight.new(shipment.dir, metadata, @options)
    stage.run
    assert stage.errors.any?(/removed/), 'stage gripes about removed barcode'
  end

  def test_metadata_mismatch_added
    spec = 'BC T bitonal 1 BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    metadata = { barcodes: shipment.barcodes.clone }
    metadata[:barcodes].pop
    stage = Postflight.new(shipment.dir, metadata, @options)
    stage.run
    assert stage.errors.any?(/added/), 'stage gripes about added barcode'
  end

  def test_feed_validate_error
    ENV['FAKE_FEED_VALIDATE_FAIL'] = '1'
    spec = 'BC T bitonal 1 T contone 2'
    shipment = TestShipment.new(test_name, spec)
    metadata = { barcodes: shipment.barcodes.clone }
    stage = Postflight.new(shipment.dir, metadata, @options)
    stage.run
    assert stage.errors.any?(/something\swent\swrong/),
           'error(s) from feed validate'
    ENV.delete 'FAKE_FEED_VALIDATE_FAIL'
  end
end
