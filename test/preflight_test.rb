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
    stage = Preflight.new(File.join(TestShipment::PATH, test_name), {},
                          @options)
    refute_nil stage, 'stage successfully created'
  end

  def test_run
    metadata = {}
    spec = 'BC T bitonal 1 BC T bitonal 1'
    shipment = TestShipment.new(test_name, spec)
    stage = Preflight.new(shipment.dir, metadata, @options)
    stage.run
    assert_equal(0, stage.errors.count, 'stage runs without errors')
    assert_equal(2, metadata[:barcodes].count,
                 'correct number of barcodes in metadata')
  end

  def test_luhn
    shipment = TestShipment.new(test_name, 'BBC')
    stage = Preflight.new(shipment.dir, {}, @options)
    stage.run
    assert_equal(1, stage.errors.count, 'stage runs with error')
    assert(stage.warnings.any?(/Luhn/), 'stage warns about Luhn check')
  end

  def test_remove_ds_store # rubocop:disable Metrics/AbcSize
    shipment = TestShipment.new(test_name, 'BC T bitonal 1')
    ds_store = File.join(shipment.dir, shipment.barcodes[0], '.DS_Store')
    FileUtils.touch(ds_store)
    assert(File.exist?(ds_store), '.DS_Store file created')
    stage = Preflight.new(shipment.dir, {}, @options)
    stage.run
    assert(stage.warnings.any?(/\.DS_Store/),
           'stage warns about removed .DS_Store')
    refute(File.exist?(ds_store), '.DS_Store file removed')
  end

  def test_remove_thumbs_db # rubocop:disable Metrics/AbcSize
    shipment = TestShipment.new(test_name, 'BC T bitonal 1')
    thumbs = File.join(shipment.dir, shipment.barcodes[0], 'Thumbs.db')
    FileUtils.touch(thumbs)
    assert(File.exist?(thumbs), 'Thumbs.db file created')
    stage = Preflight.new(shipment.dir, {}, @options)
    stage.run
    assert(stage.warnings.any?(/Thumbs\.db/),
           'stage warns about removed .DS_Store')
    refute(File.exist?(thumbs), 'Thumbs.db file removed')
  end

  def test_remove_toplevel_ds_store # rubocop:disable Metrics/AbcSize
    shipment = TestShipment.new(test_name, 'BC T bitonal 1')
    ds_store = File.join(shipment.dir, '.DS_Store')
    FileUtils.touch(ds_store)
    assert(File.exist?(ds_store), '.DS_Store file created')
    stage = Preflight.new(shipment.dir, {}, @options)
    stage.run
    assert(stage.warnings.any?(/\.DS_Store/),
           'stage warns about removed .DS_Store')
    refute(File.exist?(ds_store), '.DS_Store file removed')
  end

  def test_remove_toplevel_thumbs_db # rubocop:disable Metrics/AbcSize
    shipment = TestShipment.new(test_name, 'BC T bitonal 1')
    thumbs = File.join(shipment.dir, 'Thumbs.db')
    FileUtils.touch(thumbs)
    assert(File.exist?(thumbs), 'Thumbs.db file created')
    stage = Preflight.new(shipment.dir, {}, @options)
    stage.run
    assert(stage.warnings.any?(/Thumbs\.db/),
           'stage warns about removed .DS_Store')
    refute(File.exist?(thumbs), 'Thumbs.db file removed')
  end
end
