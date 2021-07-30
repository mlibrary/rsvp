#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'shipment'

class ShipmentTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    test_shipment = TestShipment.new(test_name)
    shipment = Shipment.new(test_shipment.directory)
    refute_nil shipment, 'shipment successfully created'
  end

  def test_directory
    test_shipment = TestShipment.new(test_name)
    shipment = Shipment.new(test_shipment.directory)
    refute_nil shipment.directory, 'shipment#directory is not nil'
    assert File.exist?(shipment.directory), 'shipment#directory exists'
    assert File.directory?(shipment.directory),
           'shipment#directory is a directory'
  end

  def test_source_directory
    test_shipment = TestShipment.new(test_name)
    shipment = Shipment.new(test_shipment.directory)
    src = shipment.source_directory
    assert_equal 'source', src.split(File::SEPARATOR)[-1],
                 'source directory is named "source"'
    assert_equal shipment.directory,
                 src.split(File::SEPARATOR)[0..-2].join(File::SEPARATOR),
                 'source directory is at top level of shipment directory'
  end

  def test_tmp_directory
    test_shipment = TestShipment.new(test_name)
    shipment = Shipment.new(test_shipment.directory)
    tmp = shipment.tmp_directory
    assert_equal 'tmp', tmp.split(File::SEPARATOR)[-1],
                 'temp directory is named "tmp"'
    assert_equal shipment.directory,
                 tmp.split(File::SEPARATOR)[0..-2].join(File::SEPARATOR),
                 'temp directory is at top level of shipment directory'
  end

  def test_barcode_from_path
    test_shipment = TestShipment.new(test_name, 'BC')
    shipment = Shipment.new(test_shipment.directory)
    barcode_file = File.join(TestShipment::PATH, test_shipment.barcodes[0],
                             'test')
    assert_equal test_shipment.barcodes[0],
                 shipment.barcode_from_path(barcode_file),
                 'barcode_from_path works'
  end

  def test_barcode_file_from_path
    test_shipment = TestShipment.new(test_name, 'BC')
    shipment = Shipment.new(test_shipment.directory)
    barcode_file = File.join(TestShipment::PATH, test_shipment.barcodes[0],
                             'test')
    assert_equal File.join(test_shipment.barcodes[0], 'test'),
                 shipment.barcode_file_from_path(barcode_file),
                 'barcode_file_from_path works'
  end

  def test_image_files
    spec = 'BC T contone 1 T contone 2 BC T contone 1 BC'
    test_shipment = TestShipment.new(test_name, spec)
    shipment = Shipment.new(test_shipment.directory)
    files = shipment.image_files
    assert_equal 3, files.count, '3 image files'
    assert_kind_of ImageFile, files[0], 'produces ImageFile'
    refute_nil files[0].barcode, 'ImageFile barcode is not nil'
    refute_nil files[0].path, 'ImageFile path is not nil'
  end

  def test_setup_source_directory # rubocop:disable Metrics/AbcSize
    test_shipment = TestShipment.new(test_name, 'BC T contone 1')
    shipment = Shipment.new(test_shipment.directory)
    shipment.setup_source_directory
    assert File.directory?(File.join(shipment.directory,
                                     shipment.barcodes[0])),
           'source/barcode directory created'
    assert File.exist?(File.join(shipment.directory,
                                 shipment.barcodes[0],
                                 '00000001.tif')),
           'source/barcode/00000001.tif directory created'
  end

  def test_restore_from_source_directory
    test_shipment = TestShipment.new(test_name, 'BC T contone 1')
    shipment = Shipment.new(test_shipment.directory)
    shipment.setup_source_directory
    tiff = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    tiff_size = File.size tiff
    `/bin/echo -n 'test' > #{tiff}`
    assert_equal 4, File.size(tiff), 'new file is 4 bytes'
    shipment.restore_from_source_directory
    assert_equal tiff_size, File.size(tiff),
                 'TIFF file is restored to original size'
  end

  def test_partial_restore_from_source_directory # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_shipment = TestShipment.new(test_name, 'BC T contone 1 BC T contone 1')
    shipment = Shipment.new(test_shipment.directory)
    shipment.setup_source_directory
    tiff0 = File.join(shipment.directory, shipment.barcodes[0], '00000001.tif')
    tiff0_size = File.size tiff0
    `/bin/echo -n 'test' > #{tiff0}`
    tiff1 = File.join(shipment.directory, shipment.barcodes[1], '00000001.tif')
    `/bin/echo -n 'test' > #{tiff1}`
    shipment.restore_from_source_directory [shipment.barcodes[0]]
    assert_equal tiff0_size, File.size(tiff0),
                 'TIFF file in restored directory at original size'
    assert_equal 4, File.size(tiff1),
                 'TIFF file in nonrestored directory at modified size'
  end

  def test_restore_from_nonexistent_source_directory
    test_shipment = TestShipment.new(test_name, 'BC T contone 1')
    shipment = Shipment.new(test_shipment.directory)
    assert_raises(Errno::ENOENT, 'raises Errno::ENOENT') do
      shipment.restore_from_source_directory
    end
  end

  def test_finalize
    test_shipment = TestShipment.new(test_name, 'BC T contone 1')
    shipment = Shipment.new(test_shipment.directory)
    shipment.setup_source_directory
    shipment.finalize
    refute File.exist?(shipment.source_directory), 'source directory deleted'
    assert shipment.metadata[:finalized], 'finalized status recorded'
    assert shipment.finalized?, 'finalized? returns true'
    assert_raises(FinalizedShipmentError) do
      shipment.setup_source_directory
    end
  end

  def test_fixity_check # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_shipment = TestShipment.new(test_name, 'BC T contone 2-3')
    shipment = Shipment.new(test_shipment.directory)
    shipment.setup_source_directory
    shipment.checksum_source_directory
    # Add 00000001.tif, change 00000002.tif, and remove 00000003.tif
    tiff1 = File.join(shipment.source_directory, shipment.barcodes[0],
                      '00000001.tif')
    refute File.exist?(tiff1), '(make sure 00000001.tif does not exist)'
    `/bin/echo -n 'test' > #{tiff1}`
    tiff2 = File.join(shipment.source_directory, shipment.barcodes[0],
                      '00000002.tif')
    `/bin/echo -n 'test' > #{tiff2}`
    tiff3 = File.join(shipment.source_directory, shipment.barcodes[0],
                      '00000003.tif')
    FileUtils.rm tiff3
    fixity = shipment.fixity_check
    assert_equal 1, fixity[:added].count, 'one file added'
    assert_equal File.join(shipment.barcodes[0], '00000001.tif'),
                 fixity[:added][0].barcode_file, '00000001.tif added'
    assert_equal 1, fixity[:changed].count, 'one file changed'
    assert_equal File.join(shipment.barcodes[0], '00000002.tif'),
                 fixity[:changed][0].barcode_file, '00000002.tif changed'
    assert_equal 1, fixity[:removed].count, 'one file changed'
    assert_equal File.join(shipment.barcodes[0], '00000003.tif'),
                 fixity[:removed][0].barcode_file, '00000003.tif removed'
  end
end
