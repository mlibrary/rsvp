#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'tagger'

class TaggerTest < Minitest::Test
  def setup
    @options = { no_progress: true }
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    stage = Tagger.new(File.join(TestShipment::PATH, test_name), {}, @options)
    refute_nil stage, 'stage successfully created'
  end

  def test_default_tags # rubocop:disable Metrics/MethodLength
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    stage = Tagger.new(shipment.dir, {}, @options)
    stage.run
    info = `tiffinfo #{tiff}`
    assert_match 'Orientation: row 0 top, col 0 lhs',
                 info, 'tiffinfo has correct default orientation'
    assert_match 'Artist: University of Michigan: Digital Conversion Unit',
                 info, 'tiffinfo has correct default DCU artist'
    refute_match(/make:/i, info, 'tiffinfo has no software tag')
    refute_match(/model:/i, info, 'tiffinfo has no scanner tag')
  end

  def test_artist_tag
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    options = { no_progress: true, tagger_artist: 'bentley' }
    stage = Tagger.new(shipment.dir, {}, options)
    stage.run
    info = `tiffinfo #{tiff}`
    assert_match(/bentley/i, info, 'tiffinfo has Bentley artist tag')
  end

  def test_unknown_artist_tag
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    options = { no_progress: true, tagger_artist: '__INVALID_ARTIST__' }
    stage = Tagger.new(shipment.dir, {}, options)
    stage.run
    assert(stage.errors.any?(/unrecognized artist/i),
           'invalid artist tag error')
  end

  def test_scanner_tag
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    options = { no_progress: true, tagger_scanner: 'copibookv' }
    stage = Tagger.new(shipment.dir, {}, options)
    stage.run
    info = `tiffinfo #{tiff}`
    assert_match('Make: i2S DigiBook', info,
                 'tiffinfo has DigiBook scanner tag')
    assert_match('Model: CopiBook V', info, 'tiffinfo has CopiBook scanner tag')
  end

  def test_unknown_scanner_tag
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    options = { no_progress: true, tagger_scanner: '__INVALID_SCANNER__' }
    stage = Tagger.new(shipment.dir, {}, options)
    stage.run
    assert(stage.errors.any?(/unrecognized scanner/i),
           'invalid scanner tag error')
  end

  def test_software_tag
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    options = { no_progress: true, tagger_software: 'limb' }
    stage = Tagger.new(shipment.dir, {}, options)
    stage.run
    info = `tiffinfo #{tiff}`
    assert_match('LIMB', info, 'tiffinfo has LIMB software tag')
  end

  def test_unknown_software_tag
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    options = { no_progress: true, tagger_software: '__INVALID_SOFTWARE__' }
    stage = Tagger.new(shipment.dir, {}, options)
    stage.run
    assert(stage.errors.any?(/unrecognized software/i),
           'invalid software tag error')
  end
end
