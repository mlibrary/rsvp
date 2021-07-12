#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'tiff_validator'

class TIFFValidatorTest < Minitest::Test
  def setup
    @config = Config.new({ no_progress: true })
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    shipment = TestShipment.new(test_name)
    stage = TIFFValidator.new(shipment, config: @config)
    refute_nil stage, 'stage successfully created'
  end

  def test_run_without_errors
    spec = 'BC T bitonal 1 T contone 2'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment, config: @config)
    stage.run!
    assert_equal(0, stage.errors.count, 'stage runs without errors')
  end

  def test_16bps_fails
    spec = 'BC T bad_16bps 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment, config: @config)
    stage.run!
    assert_equal(1, stage.errors.count, '16bps TIFF rejected')
  end

  def test_pixelspercentimeter_fails
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment, config: @config)
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    `convert #{tiff} -units PixelsPerCentimeter #{tiff}`
    stage.run!
    assert(stage.errors.any? { |e| %r{pixels/cm}.match? e.to_s },
           'PixelsPerCentimeter TIFF rejected')
  end

  def test_bitonal_3spp_fails
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment, config: @config)
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    `tiffset -s 277 '3' #{tiff}`
    stage.run!
    assert(stage.errors.any? { |e| /SPP\s3\swith\s1\sBPS/i.match? e.to_s },
           '1 BPS 3 SPP TIFF rejected')
  end

  def test_bitonal_resolution_fails
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment, config: @config)
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    `convert #{tiff} -density 100x100 -units pixelsperinch #{tiff}`
    stage.run!
    assert(stage.errors.any? { |e| /100x100\sbitonal/i.match? e.to_s },
           '100x100 bitonal TIFF rejected')
  end

  def test_contone_2spp_fails
    spec = 'BC T contone 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment, config: @config)
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    `tiffset -s 277 '2' #{tiff}`
    stage.run!
    assert(stage.errors.any? { |e| /SPP\s2\swith\s8\sBPS/i.match? e.to_s },
           '8 BPS 2 SPP TIFF rejected')
  end

  def test_contone_resolution_fails
    spec = 'BC T contone 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment, config: @config)
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    `convert #{tiff} -density 100x100 -units pixelsperinch #{tiff}`
    stage.run!
    assert(stage.errors.any? { |e| /100x100\scontone/i.match? e.to_s },
           '100x100 contone TIFF rejected')
  end

  def test_garbage_tiff_fails
    spec = 'BC T contone 1'
    shipment = TestShipment.new(test_name, spec)
    stage = TIFFValidator.new(shipment, config: @config)
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    `/bin/echo -n 'test' > #{tiff}`
    stage.run!
    assert(stage.errors.count == 1, 'garbage TIFF generates one error')
    assert(stage.errors.any? { |e| /cannot read tiff header/i.match? e.to_s },
           'garbage TIFF rejected with message about TIFF header')
  end
end
