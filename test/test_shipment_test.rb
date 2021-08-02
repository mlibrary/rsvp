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

  def test_generate_test_shipment_barcode # rubocop:disable Metrics/AbcSize
    shipment = TestShipment.new(test_name, 'BC')
    assert_equal 1, shipment.barcodes.count, 'correct number of barcodes'
    assert File.directory?(shipment.directory), "#{test_name} is directory"
    barcode_dir = File.join(shipment.directory,
                            shipment.barcode_to_path(shipment.barcodes[0]))
    assert File.directory?(barcode_dir), "#{shipment.barcodes[0]} is directory"
    assert Luhn.valid?(shipment.barcodes[0]),
           "barcode #{shipment.barcodes[0]} valid"
  end

  def test_generate_test_shipment_bogus_barcode # rubocop:disable Metrics/AbcSize
    shipment = TestShipment.new(test_name, 'BBC')
    assert_equal 1, shipment.barcodes.count, 'correct number of barcodes'
    assert File.directory?(shipment.directory), "#{test_name} is directory"
    assert File.directory?(File.join(shipment.directory,
                                     shipment.barcodes[0])),
           "#{shipment.barcodes[0]} is directory"
    refute Luhn.valid?(shipment.barcodes[0]),
           "barcode #{shipment.barcodes[0]} invalid"
  end

  def test_generate_test_shipment_tiff_files
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 F empty.txt')
    tiff = File.join(shipment.directory, shipment.barcodes[0],
                     '00000001.tif')
    assert File.exist?(tiff), '000000001.tif is copied'
    txt = File.join(shipment.directory, shipment.barcodes[0], 'empty.txt')
    assert File.exist?(txt), 'empty.txt is created'
  end

  def test_generate_test_shipment_tiff_file_range
    shipment = TestShipment.new(test_name, 'BC T contone 1-8')
    (1..8).each do |n|
      tiff = File.join(shipment.directory, shipment.barcodes[0],
                       format('%<filename>08d.tif', { filename: n }))
      assert File.exist?(tiff), "#{tiff} in file range"
    end
  end

  def test_generate_test_shipment_jp2_files
    shipment = TestShipment.new(test_name, 'BC J contone 1')
    jp2 = File.join(shipment.directory, shipment.barcodes[0], '00000001.jp2')
    assert File.exist?(jp2), '000000001.jp2 is copied'
  end

  def test_generate_test_shipment_jp2_file_range
    shipment = TestShipment.new(test_name, 'BC J contone 1-8')
    (1..8).each do |n|
      jp2 = File.join(shipment.directory, shipment.barcodes[0],
                      format('%<filename>08d.jp2', { filename: n }))
      assert File.exist?(jp2), "#{jp2} in file range"
    end
  end

  def test_dir_opcode
    shipment = TestShipment.new(test_name, 'BC DIR F test')
    file = File.join(shipment.directory, 'test')
    assert File.exist?(file), 'test file creasted at top level'
  end

  def test_unknown_opcode
    assert_raises(StandardError, 'raises unknown opcode') do
      TestShipment.new(test_name, 'ZZZZZ')
    end
  end

  def test_unknown_tiff_format
    assert_raises(StandardError, 'raises unknown tiff format') do
      TestShipment.new(test_name, 'BC T contone ZZZZZ')
    end
  end

  def test_unknown_jp2_format
    assert_raises(StandardError, 'raises unknown jp2 format') do
      TestShipment.new(test_name, 'BC J contone ZZZZZ')
    end
  end
end

class DLXSTestShipmentTest < Minitest::Test
  def test_generate_test_shipment_dlxs_barcode
    shipment = DLXSTestShipment.new(test_name, 'BC')
    assert_equal 1, shipment.ordered_barcodes.count,
                 'correct number of ordered barcodes'
    (vol, num) = shipment.ordered_barcodes[0].split '/'
    assert File.directory?(File.join(shipment.directory, vol)),
           'shipment/volume is directory'
    assert File.directory?(File.join(shipment.directory, vol, num)),
           'shipment/volume/number is directory'
  end
end
