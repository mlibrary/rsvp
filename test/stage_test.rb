#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'stage'

class StageTest < Minitest::Test
  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment, {})
    refute_nil stage, 'stage successfully created'
  end

  def test_run
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment, {})
    assert_raises(StandardError, 'raises for Stage#run') { stage.run }
  end

  def test_progress
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment, { no_progress: false })
    assert_output(/\u2588/) do
      stage.write_progress(1, 10)
    end
  end

  def test_no_progress
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment, { no_progress: true })
    assert_silent do
      stage.write_progress(1, 10)
    end
  end

  def test_cleanup_tempdirs
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment, {})
    tempdir = stage.create_tempdir
    assert File.exist?(tempdir), 'tempdir created'
    stage.cleanup
    refute File.exist?(tempdir), 'tempdir deleted by #cleanup'
  end

  def test_cleanup_delete_on_success
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment, {})
    temp = File.join(shipment.directory, shipment.barcodes[0], 'temp.txt')
    FileUtils.touch(temp)
    stage.delete_on_success temp
    stage.cleanup
    refute File.exist?(temp), 'file deleted by #delete_on_success'
  end

  def test_unknown_shipment_class
    assert_raises(StandardError, 'raises unknown shipment class') do
      Stage.new('This is a String', {})
    end
  end
end
