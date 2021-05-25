#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'dlxs_compressor'
require 'fixtures'

class DLXSCompressorTest < Minitest::Test
  def setup
    # For testing under Docker, fall back to ImageMagick instead of Kakadu
    ENV['KAKADONT'] = '1'
    @config = Config.new({ no_progress: true })
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    shipment = TestShipment.new(test_name)
    stage = DLXSCompressor.new(shipment, @config)
    refute_nil stage, 'stage successfully created'
  end

  def test_run # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment = TestShipment.new(test_name, 'BC T contone 1')
    stage = Compressor.new(shipment, @config)
    stage.run
    assert_equal(0, stage.errors.count, 'compressor stage runs without errors')
    stage = DLXSCompressor.new(shipment, @config)
    stage.run
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    assert File.exist?(tiff), '00000001.tif exists'
    jp2 = File.join(shipment.directory, shipment.barcodes[0], '00000001.jp2')
    refute File.exist?(jp2), '00000001.jp2 does not exist'
    jp2 = File.join(shipment.directory, shipment.barcodes[0], 'p0000001.jp2')
    assert File.exist?(jp2), 'p0000001.jp2 exists'
  end
end
