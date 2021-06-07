#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'agenda'

class AgendaTest < Minitest::Test
  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    shipment = TestShipment.new(test_name)
    processor = Processor.new(shipment.directory, {})
    agenda = Agenda.new processor.shipment, processor.stages
    refute_nil agenda, 'agenda successfully created'
  end

  def test_for_stage
    shipment = TestShipment.new(test_name, 'BC T contone 1 BC T contone 1')
    processor = Processor.new(shipment.directory, {})
    agenda = Agenda.new processor.shipment, processor.stages
    assert_equal processor.shipment.barcodes,
                 agenda.for_stage(processor.stages[0]),
                 'first stage has all shipment barcodes'
  end

  def test_update # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment = TestShipment.new(test_name, 'BC T contone 1 BC T contone 1')
    processor = Processor.new(shipment.directory, {})
    agenda = Agenda.new processor.shipment, processor.stages
    err = Error.new 'test error', processor.shipment.barcodes[0],
                    File.join(processor.shipment.directory,
                              processor.shipment.barcodes[0],
                              '00000001.tif')
    processor.stages[0].add_error err
    agenda.update processor.stages[0]
    assert_equal processor.shipment.barcodes[1..],
                 agenda.for_stage(processor.stages[1]),
                 'subsequent stage has one less barcode'
  end

  def test_update_fatal_error # rubocop:disable Metrics/AbcSize
    shipment = TestShipment.new(test_name, 'BC T contone 1 BC T contone 1')
    processor = Processor.new(shipment.directory, {})
    agenda = Agenda.new processor.shipment, processor.stages
    err = Error.new 'fatal error'
    processor.stages[0].add_error err
    agenda.update processor.stages[0]
    assert_equal 0, agenda.for_stage(processor.stages[1]).count,
                 'subsequent stage has no barcodes'
  end
end
