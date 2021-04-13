#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'preflight'

class PreflightTest < Minitest::Test
  def setup
    @options = { no_progress: true }
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    shipment = TestShipment.new(test_name)
    stage = Preflight.new(shipment, {}, @options)
    refute_nil stage, 'stage successfully created'
  end

  def test_run
    metadata = {}
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 BC T bitonal 1')
    stage = Preflight.new(shipment, metadata, @options)
    stage.run
    assert_equal(0, stage.errors.count, 'stage runs without errors')
    assert_equal(2, metadata[:barcodes].count,
                 'correct number of barcodes in metadata')
    assert_equal(2, metadata[:checksums].count,
                 'correct number of checksums in metadata')
  end

  def test_luhn
    shipment = TestShipment.new(test_name, 'BBC')
    stage = Preflight.new(shipment, {}, @options)
    stage.run
    assert_equal(1, stage.errors.count, 'stage runs with error')
    assert(stage.warnings.any?(/Luhn/), 'stage warns about Luhn check')
  end

  def test_remove_ds_store
    shipment = TestShipment.new(test_name, 'BC T bitonal 1')
    ds_store = File.join(shipment.directory, shipment.barcodes[0], '.DS_Store')
    FileUtils.touch(ds_store)
    assert(File.exist?(ds_store), '.DS_Store file created')
    stage = Preflight.new(shipment, {}, @options)
    stage.run
    assert(stage.warnings.any?(/\.DS_Store/),
           'stage warns about removed .DS_Store')
    refute(File.exist?(ds_store), '.DS_Store file removed')
  end

  def test_remove_thumbs_db
    shipment = TestShipment.new(test_name, 'BC T bitonal 1')
    thumbs = File.join(shipment.directory, shipment.barcodes[0], 'Thumbs.db')
    FileUtils.touch(thumbs)
    assert(File.exist?(thumbs), 'Thumbs.db file created')
    stage = Preflight.new(shipment, {}, @options)
    stage.run
    assert(stage.warnings.any?(/Thumbs\.db/),
           'stage warns about removed .DS_Store')
    refute(File.exist?(thumbs), 'Thumbs.db file removed')
  end

  def test_remove_toplevel_ds_store
    shipment = TestShipment.new(test_name, 'BC T bitonal 1')
    ds_store = File.join(shipment.directory, '.DS_Store')
    FileUtils.touch(ds_store)
    assert(File.exist?(ds_store), '.DS_Store file created')
    stage = Preflight.new(shipment, {}, @options)
    stage.run
    assert(stage.warnings.any?(/\.DS_Store/),
           'stage warns about removed .DS_Store')
    refute(File.exist?(ds_store), '.DS_Store file removed')
  end

  def test_remove_toplevel_thumbs_db
    shipment = TestShipment.new(test_name, 'BC T bitonal 1')
    thumbs = File.join(shipment.directory, 'Thumbs.db')
    FileUtils.touch(thumbs)
    assert(File.exist?(thumbs), 'Thumbs.db file created')
    stage = Preflight.new(shipment, {}, @options)
    stage.run
    assert(stage.warnings.any?(/Thumbs\.db/),
           'stage warns about removed .DS_Store')
    refute(File.exist?(thumbs), 'Thumbs.db file removed')
  end

  def test_barcode_directory_errors_and_warnings # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment = TestShipment.new(test_name, 'BC F spurious_file')
    checksum_md5 = File.join(shipment.directory, shipment.barcodes[0],
                             'checksum.md5')
    FileUtils.touch(checksum_md5)
    Dir.mkdir(File.join(shipment.directory, shipment.barcodes[0], 'spurious_d'))
    stage = Preflight.new(shipment, {}, @options)
    stage.run
    assert(stage.errors.any?(/spurious_file/),
           'stage fails with unknown file')
    assert(stage.errors.any?(/spurious_d/),
           'stage fails with barcode subdirectory')
    assert(stage.warnings.any?(/md5\signored/),
           'stage warns about ignored checksum.md5 file')
  end

  def test_shipment_directory_errors
    shipment = TestShipment.new(test_name, 'F spurious_file')
    stage = Preflight.new(shipment, {}, @options)
    stage.run
    assert(stage.errors.any?(/no\sbarcode\sdirectories/),
           'stage fails with no barcode directories')
    assert(stage.errors.any?(/spurious_file/),
           'stage fails with unknown file')
  end
end
