#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'pagination_check'

class PaginationCheckTest < Minitest::Test
  def setup
    @config = Config.new({ no_progress: true })
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    shipment = TestShipment.new(test_name)
    stage = PaginationCheck.new(shipment, @config)
    refute_nil stage, 'stage successfully created'
  end

  def test_run
    shipment = TestShipment.new(test_name, 'BC T bitonal 1-5')
    stage = PaginationCheck.new(shipment, @config)
    stage.run
    assert(stage.errors.none?, 'no errors')
    assert(stage.warnings.none?, 'no warnings')
  end

  def test_missing # rubocop:disable Metrics/AbcSize
    shipment = TestShipment.new(test_name, 'BC T bitonal 1-2 T bitonal 4-5')
    stage = PaginationCheck.new(shipment, @config)
    stage.run
    assert(stage.errors.count == 1, 'one missing page error')
    assert_equal(stage.errors[0].barcode, shipment.barcodes[0],
                 'error barcode is shipment barcode')
    assert_match(/missing/, stage.errors[0].description,
                 'error contains "missing"')
  end

  def test_missing_range
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 T bitonal 5')
    stage = PaginationCheck.new(shipment, @config)
    stage.run
    assert(stage.errors.count == 1, 'one missing page range error')
    assert_match(/2-4/, stage.errors[0].description, 'error contains range')
  end

  def test_duplicate
    shipment = TestShipment.new(test_name, 'BC T bitonal 1 J contone 1')
    stage = PaginationCheck.new(shipment, @config)
    stage.run
    assert(stage.errors.count == 1, 'one error from duplicate page')
    assert_match(/duplicate/, stage.errors[0].description,
                 'error contains "duplicate"')
  end
end
