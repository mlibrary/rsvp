#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'stage'

class StageTest < Minitest::Test
  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    stage = Stage.new(File.join(TestShipment::PATH, test_name), {}, {})
    refute_nil stage, 'stage successfully created'
  end

  def test_run
    stage = Stage.new(File.join(TestShipment::PATH, test_name), {}, {})
    assert_raises(StandardError, 'raises for Stage#run') { stage.run }
  end

  def test_progress
    stage = Stage.new(File.join(TestShipment::PATH, test_name), {},
                      { no_progress: false })
    assert_output(/\u2588/) do
      stage.write_progress(1, 10)
    end
  end

  def test_no_progress
    stage = Stage.new(File.join(TestShipment::PATH, test_name), {},
                      { no_progress: true })
    assert_silent do
      stage.write_progress(1, 10)
    end
  end

  def test_barcode_from_file
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment.dir, {}, {})
    barcode_path = File.join(TestShipment::PATH, shipment.barcodes[0], 'test')
    assert_equal shipment.barcodes[0], stage.barcode_from_file(barcode_path),
                 'barcode_from_file works'
  end

  def test_cleanup_tempdirs
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment.dir, {}, {})
    tempdir = stage.create_tempdir
    stage.cleanup
    refute File.exist?(tempdir), 'tempdir deleted by #cleanup'
  end
end
