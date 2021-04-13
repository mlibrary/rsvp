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

  def test_barcode_from_path
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment.dir, {}, {})
    barcode_file = File.join(TestShipment::PATH, shipment.barcodes[0], 'test')
    assert_equal shipment.barcodes[0], stage.barcode_from_path(barcode_file),
                 'barcode_from_path works'
  end

  def test_barcode_file_from_path
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment.dir, {}, {})
    barcode_file = File.join(TestShipment::PATH, shipment.barcodes[0], 'test')
    assert_equal File.join(shipment.barcodes[0], 'test'),
                 stage.barcode_file_from_path(barcode_file),
                 'barcode_file_from_path works'
  end

  def test_tempdir
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment.dir, {}, {})
    tempdir = stage.create_tempdir
    assert File.directory?(tempdir), 'tempdir created'
    assert_equal 'tmp', tempdir.split(File::SEPARATOR)[-2],
                 'temp directory is named "tmp"'
    assert_equal stage.directory,
                 tempdir.split(File::SEPARATOR)[0..-3].join(File::SEPARATOR),
                 'temp directory is at top level of shipment directory'
  end

  def test_cleanup_tempdirs
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment.dir, {}, {})
    tempdir = stage.create_tempdir
    stage.cleanup
    refute File.exist?(tempdir), 'tempdir deleted by #cleanup'
  end

  def test_cleanup_delete_on_success
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment.dir, {}, {})
    temp = File.join(shipment.dir, shipment.barcodes[0], 'temp.txt')
    FileUtils.touch(temp)
    stage.delete_on_success temp
    stage.cleanup
    refute File.exist?(temp), 'file deleted by #delete_on_success'
  end

  def test_log
    shipment = TestShipment.new(test_name, 'BC')
    stage = Stage.new(shipment.dir, {}, {})
    stage.log('testlog')
    refute_nil stage.data[:log], 'stage#data[:log] is not nil'
    assert_equal 1, stage.data[:log].size, 'one log entry'
    assert_equal 'testlog', stage.data[:log][0], 'log entry is "testlog"'
  end
end
