#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'compressor'
require 'fixtures'

class CompressorTest < Minitest::Test
  def setup
    # For testing under Docker, fall back to ImageMagick instead of Kakadu
    ENV['KAKADONT'] = '1'
    @options = { no_progress: true }
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    stage = Compressor.new(File.join(TestShipment::PATH, test_name), {},
                           @options)
    refute_nil stage, 'stage successfully created'
  end

  def test_run # rubocop:disable Metrics/AbcSize
    spec = 'BC T bitonal 1 T contone 2'
    shipment = TestShipment.new(test_name, spec)
    stage = Compressor.new(shipment.dir, {}, @options)
    stage.run
    assert_equal(0, stage.errors.count, 'stage runs without errors')
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    assert File.exist?(tiff), '00000001.tif exists'
    jp2 = File.join(shipment.dir, shipment.barcodes[0], '00000002.jp2')
    assert File.exist?(jp2), '00000002.jp2 exists'
  end

  def test_set_tiff_date_time
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    stage = Compressor.new(shipment.dir, {}, @options)
    stage.send(:write_tiff_date_time, tiff)
    tiffinfo = `tiffinfo #{tiff}`
    assert_match(/DateTime:\s\d{4}:\d{2}:\d{2}\s\d{2}:\d{2}:\d{2}/, tiffinfo,
                 'TIFF DateTime in %Y:%m:%d %H:%M:%S format')
  end

  def test_16bps_fails
    spec = 'BC T bad_16bps 1'
    shipment = TestShipment.new(test_name, spec)
    stage = Compressor.new(shipment.dir, {}, @options)
    stage.run
    assert_equal(1, stage.errors.count, 'stage fails with 16bps TIFF')
  end

  def test_zero_length_fails
    spec = 'BC F 00000001.tif'
    shipment = TestShipment.new(test_name, spec)
    stage = Compressor.new(shipment.dir, {}, @options)
    stage.run
    assert_equal(1, stage.errors.count, 'stage fails with 16bps TIFF')
  end

  def test_alpha_channel
    spec = 'BC T contone 1'
    shipment = TestShipment.new(test_name, spec)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    `convert #{tiff} -alpha on #{tiff}`
    stage = Compressor.new(shipment.dir, {}, @options)
    stage.run
    assert_equal(0, stage.errors.count, 'stage runs without errors')
  end

  def test_icc_profile
    spec = 'BC T contone 1'
    shipment = TestShipment.new(test_name, spec)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    profile_path = File.join(Fixtures::TEST_FIXTURES_PATH, 'sRGB2014.icc')
    `convert #{tiff} -profile #{profile_path} #{tiff}`
    stage = Compressor.new(shipment.dir, {}, @options)
    stage.run
    assert_equal(0, stage.errors.count, 'stage runs without errors')
  end

  def test_software
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    `tiffset -s 305 'BOGUS SOFTWARE v1.0' #{tiff}`
    stage = Compressor.new(shipment.dir, {}, @options)
    stage.run
    assert_equal(0, stage.errors.count, 'stage runs without errors')
    assert_match(/BOGUS\sSOFTWARE/, `tiffinfo #{tiff}`,
                 '305 software tag is preserved')
  end
end
