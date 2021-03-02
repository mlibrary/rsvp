#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'test_shipment'

class TestShipmentTest < Minitest::Test
  def teardown
    TestShipment.remove_test_shipments
  end

  def test_valid_barcodes
    100.times do
      barcode = TestShipment.generate_barcode(true)
      assert Luhn.valid?(barcode), "generate_barcode #{barcode} valid"
    end
  end

  def test_invalid_barcodes
    100.times do
      barcode = TestShipment.generate_barcode(false)
      refute Luhn.valid?(barcode), "generate_barcode #{barcode} valid"
    end
  end

  def test_generate_test_shipment_barcode # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    spec = 'BC'
    name = [self.class.to_s, __method__.to_s].join '_'
    shipment = TestShipment.new(name, spec)
    assert_equal 1, shipment.barcodes.count, 'correct number of barcodes'
    assert File.directory?(File.join(TestShipment::PATH, name)),
           "#{name} is directory"
    assert File.directory?(File.join(TestShipment::PATH, name,
                                     shipment.barcodes[0])),
           "#{shipment.barcodes[0]} is directory"
    assert Luhn.valid?(shipment.barcodes[0]),
           "barcode #{shipment.barcodes[0]} valid"
  end

  def test_generate_test_shipment_bogus_barcode # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    spec = 'BBC'
    name = [self.class.to_s, __method__.to_s].join '_'
    shipment = TestShipment.new(name, spec)
    assert_equal 1, shipment.barcodes.count, 'correct number of barcodes'
    assert File.directory?(File.join(TestShipment::PATH, name)),
           "#{name} is directory"
    assert File.directory?(File.join(TestShipment::PATH, name,
                                     shipment.barcodes[0])),
           "#{shipment.barcodes[0]} is directory"
    refute Luhn.valid?(shipment.barcodes[0]),
           "barcode #{shipment.barcodes[0]} invalid"
  end

  def test_generate_test_shipment_tiff_files
    spec = 'BC T bitonal 1 F empty.txt'
    name = [self.class.to_s, __method__.to_s].join '_'
    shipment = TestShipment.new(name, spec)
    tiff = File.join(TestShipment::PATH, name, shipment.barcodes[0],
                     '00000001.tif')
    assert File.exist?(tiff), '000000001.tif is copied'
    txt = File.join(TestShipment::PATH, name, shipment.barcodes[0], 'empty.txt')
    assert File.exist?(txt), 'empty.txt is created'
  end

  def test_generate_test_shipment_tiff_file_range
    spec = 'BC T contone 1-8'
    name = [self.class.to_s, __method__.to_s].join '_'
    shipment = TestShipment.new(name, spec)
    (1..8).each do |n|
      tiff = File.join(TestShipment::PATH, name, shipment.barcodes[0],
                       format('%<filename>08d.tif', { filename: n }))
      assert File.exist?(tiff), "#{tiff} in file range"
    end
  end

  def test_generate_test_shipment_jp2_files
    spec = 'BC J contone 1'
    name = [self.class.to_s, __method__.to_s].join '_'
    shipment = TestShipment.new(name, spec)
    jp2 = File.join(TestShipment::PATH, name, shipment.barcodes[0],
                    '00000001.jp2')
    assert File.exist?(jp2), '000000001.jp2 is copied'
  end

  def test_generate_test_shipment_jp2_file_range
    spec = 'BC J contone 1-8'
    name = [self.class.to_s, __method__.to_s].join '_'
    shipment = TestShipment.new(name, spec)
    (1..8).each do |n|
      jp2 = File.join(TestShipment::PATH, name, shipment.barcodes[0],
                      format('%<filename>08d.jp2', { filename: n }))
      assert File.exist?(jp2), "#{jp2} in file range"
    end
  end
end
