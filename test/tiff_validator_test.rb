#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'tiff_validator'

class TIFFValidatorTest < Minitest::Test
  def setup
    @options = { no_progress: true }
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    shipment = TestShipment.new(test_name, '')
    stage = TIFFValidator.new(shipment.dir, {}, @options)
    refute_nil stage, 'stage successfully created'
  end

  def test_run_without_errors
    spec = 'BC T bitonal 1 T contone 2'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment.dir, {}, @options)
    stage.run
    assert_equal(0, stage.errors.count, 'stage runs without errors')
  end

  def test_16bps_fails
    spec = 'BC T bad_16bps 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment.dir, {}, @options)
    stage.run
    assert_equal(1, stage.errors.count, '16bps TIFF rejected')
  end

  def test_pixelspercentimeter_fails
    spec = 'BC T bad_16bps 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment.dir, {}, @options)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    `convert #{tiff} -units PixelsPerCentimeter #{tiff}`
    stage.run
    assert(stage.errors.any?(%r{pixels/cm}),
           'PixelsPerCentimeter TIFF rejected')
  end
end
