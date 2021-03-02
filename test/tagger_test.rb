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

  def test_tags
    spec = 'BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    tiff = File.join(shipment.dir, shipment.barcodes[0], '00000001.tif')
    stage = Tagger.new(shipment.dir, {}, @options)
    stage.run
    info = `tiffinfo #{tiff}`
    assert_match 'Orientation: row 0 top, col 0 lhs',
                 info, 'tiffinfo has correct orientation'
    assert_match 'Artist: University of Michigan: Digital Conversion Unit',
                 info, 'tiffinfo has correct artist'
  end
end
