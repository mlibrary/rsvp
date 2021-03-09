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
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment.dir, {}, @options)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    `convert #{tiff} -units PixelsPerCentimeter #{tiff}`
    stage.run
    assert(stage.errors.any?(%r{pixels/cm}),
           'PixelsPerCentimeter TIFF rejected')
  end

  def test_bitonal_3spp_fails
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment.dir, {}, @options)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    `tiffset -s 277 '3' #{tiff}`
    stage.run
    assert(stage.errors.any?(/SPP\s3\swith\s1\sBPS/i),
           '1 BPS 3 SPP TIFF rejected')
  end

  def test_bitonal_resolution_fails
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment.dir, {}, @options)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    `convert #{tiff} -density 100x100 -units pixelsperinch #{tiff}`
    stage.run
    assert(stage.errors.any?(/100x100\sbitonal/),
           '100x100 bitonal TIFF rejected')
  end

  def test_contone_2spp_fails
    spec = 'BC T contone 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment.dir, {}, @options)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    `tiffset -s 277 '2' #{tiff}`
    stage.run
    assert(stage.errors.any?(/SPP\s2\swith\s8\sBPS/i),
           '8 BPS 2 SPP TIFF rejected')
  end

  def test_contone_resolution_fails
    spec = 'BC T contone 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment.dir, {}, @options)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    `convert #{tiff} -density 100x100 -units pixelsperinch #{tiff}`
    stage.run
    assert(stage.errors.any?(/100x100\scontone/),
           '100x100 contone TIFF rejected')
  end
end
