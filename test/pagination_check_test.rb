#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'pagination_check'

class PaginationCheckTest < Minitest::Test
  def setup
    @options = { no_progress: true }
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    stage = PaginationCheck.new(TestShipment::PATH, {}, @options)
    refute_nil stage, 'stage successfully created'
  end

  def test_run
    spec = 'BC T bitonal 1-5'
    shipment = TestShipment.new(test_name, spec)
    stage = PaginationCheck.new(shipment.dir, {}, @options)
    stage.run
    assert(stage.errors.none?, 'no errors')
    assert(stage.warnings.none?, 'no warnings')
  end

  def test_missing
    spec = 'BC T bitonal 1-2 T bitonal 4-5'
    shipment = TestShipment.new(test_name, spec)
    stage = PaginationCheck.new(shipment.dir, {}, @options)
    stage.run
    assert(stage.errors.count == 1, 'one missing page error')
    assert_match(/missing/, stage.errors[0], 'error contains "missing"')
  end

  def test_missing_range
    spec = 'BC T bitonal 1 T bitonal 5'
    shipment = TestShipment.new(test_name, spec)
    stage = PaginationCheck.new(shipment.dir, {}, @options)
    stage.run
    assert(stage.errors.count == 1, 'one missing page range error')
    assert_match(/2-4/, stage.errors[0], 'error contains range')
  end

  def test_duplicate
    spec = 'BC T bitonal 1 J contone 1'
    shipment = TestShipment.new(test_name, spec)
    stage = PaginationCheck.new(shipment.dir, {}, @options)
    stage.run
    assert(stage.errors.count == 1, 'one error from duplicate page')
    assert_match(/duplicate/, stage.errors[0], 'error contains "duplicate"')
  end
end
