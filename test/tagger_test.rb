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
    shipment = TestShipment.new(test_name)
    stage = Tagger.new(shipment, {}, @options)
    refute_nil stage, 'stage successfully created'
  end

  def test_default_tags # rubocop:disable Metrics/MethodLength
    shipment = TestShipment.new(test_name, 'BC T bitonal 1')
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    stage = Tagger.new(shipment, {}, @options)
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
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    options = { no_progress: true, tagger_artist: 'bentley' }
    stage = Tagger.new(shipment, {}, options)
    stage.run
    info = `tiffinfo #{tiff}`
    assert_match(/bentley/i, info, 'tiffinfo has Bentley artist tag')
  end

  def test_scanner_tag
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    options = { no_progress: true, tagger_scanner: 'copibookv' }
    stage = Tagger.new(shipment, {}, options)
    stage.run
    info = `tiffinfo #{tiff}`
    assert_match('Make: i2S DigiBook', info,
                 'tiffinfo has DigiBook scanner tag')
    assert_match('Model: CopiBook V', info, 'tiffinfo has CopiBook scanner tag')
  end

  def test_software_tag
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    options = { no_progress: true, tagger_software: 'limb' }
    stage = Tagger.new(shipment, {}, options)
    stage.run
    info = `tiffinfo #{tiff}`
    assert_match('LIMB', info, 'tiffinfo has LIMB software tag')
  end
end

class TaggerCustomTagTest < Minitest::Test
  def setup
    @options = { no_progress: true }
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def test_custom_artist_tag # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    artist = 'University of Michigan: Secret Vaults'
    shipment = TestShipment.new(test_name, 'BC T bitonal 1')
    options = { no_progress: true, tagger_artist: artist }
    stage = Tagger.new(shipment, {}, options)
    stage.run
    assert(stage.errors.count.zero?, 'no errors generated')
    assert(stage.warnings.any?(/custom\sartist/i),
           'warns about custom software string')
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    info = `tiffinfo #{tiff}`
    assert_match("Artist: #{artist}", info, 'tiffinfo has custom artist tag')
  end

  def test_custom_scanner_tag # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment = TestShipment.new(test_name, 'BC T bitonal 1')
    options = { no_progress: true, tagger_scanner: 'Scans-R-Us|F-150 Flatbed' }
    stage = Tagger.new(shipment, {}, options)
    stage.run
    assert(stage.errors.count.zero?, 'no errors generated')
    assert(stage.warnings.any?(/custom\sscanner/i),
           'warns about custom software string')
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    info = `tiffinfo #{tiff}`
    assert_match('Make: Scans-R-Us', info,
                 'tiffinfo has custom scanner make tag')
    assert_match('Model: F-150 Flatbed', info,
                 'tiffinfo has custom scanner model tag')
  end

  def test_bogus_custom_scanner_tag
    shipment = TestShipment.new(test_name, 'BC T bitonal 1')
    options = { no_progress: true, tagger_scanner: 'some random string' }
    stage = Tagger.new(shipment, {}, options)
    stage.run
    assert(stage.errors.any?(/pipe-delimited/),
           'generates pipe-delimited error')
  end

  def test_custom_software_tag # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    software = 'WhizzySoft ScanR v33'
    shipment = TestShipment.new(test_name, 'BC T bitonal 1')
    options = { no_progress: true, tagger_software: software }
    stage = Tagger.new(shipment, {}, options)
    stage.run
    assert(stage.errors.count.zero?, 'no errors generated')
    assert(stage.warnings.any?(/custom\ssoftware/i),
           'warns about custom software string')
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    info = `tiffinfo #{tiff}`
    assert_match("Software: #{software}", info,
                 'tiffinfo has custom software tag')
  end
end
