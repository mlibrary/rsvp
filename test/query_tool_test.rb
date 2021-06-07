#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'stringio'
require 'query_tool'

class QueryToolTestTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def test_new
    shipment = TestShipment.new(test_name)
    processor = Processor.new(shipment.directory)
    tool = QueryTool.new(processor)
    refute_nil tool, 'query tool successfully created'
  end

  def test_agenda_cmd # rubocop:disable Metrics/MethodLength
    test_shipment = TestShipment.new(test_name, 'BC T contone 1')
    processor = Processor.new(test_shipment.directory)
    tool = QueryTool.new(processor)
    out, _err = capture_io do
      tool.agenda_cmd
    end
    out = out.decolorize
    processor.stages.each do |stage|
      assert_match "#{stage.name}\n  (all barcodes)", out,
                   "#{stage.name} all barcodes"
    end
  end

  def test_agenda_cmd_no_agenda
    test_shipment = TestShipment.new(test_name, 'BC T contone 1')
    processor = Processor.new(test_shipment.directory)
    capture_io do
      processor.run
    end
    tool = QueryTool.new(processor)
    out, _err = capture_io do
      tool.send :agenda_cmd
    end
    assert_match(/no agenda/i, out, 'no agenda after completion')
  end

  def test_errors_cmd # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_shipment = TestShipment.new(test_name, 'BC T contone 1 BC T contone 1')
    processor = Processor.new(test_shipment.directory, { no_progress: 1 })
    shipment = processor.shipment
    stage = processor.stages[0]
    tiff1 = File.join(shipment.barcode_directory(shipment.barcodes[0]),
                      '00000001.tif')
    stage.add_error Error.new('err 1', shipment.barcodes[0], tiff1)
    tiff2 = File.join(shipment.barcode_directory(shipment.barcodes[1]),
                      '00000001.tif')
    stage.add_error Error.new('err 2', shipment.barcodes[1], tiff2)
    tool = QueryTool.new(processor)
    out, _err = capture_io do
      tool.errors_cmd
    end
    assert_match tiff1, out, 'reports errors for both files'
    assert_match shipment.barcodes[0], out, 'reports errors for both barcodes'
    assert_match tiff2, out, 'reports errors for both files'
    assert_match shipment.barcodes[1], out, 'reports errors for both barcodes'
    out, _err = capture_io do
      tool.errors_cmd shipment.barcodes[0]
    end
    assert_match tiff1, out, 'reports error for first file'
    assert_match shipment.barcodes[0], out, 'reports error for first barcode'
    refute_match tiff2, out, 'no error for second file'
    refute_match shipment.barcodes[1], out, 'no error for second barcode'
  end

  def test_warnings_cmd # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_shipment = TestShipment.new(test_name, 'BC T contone 1 BC T contone 1')
    processor = Processor.new(test_shipment.directory, { no_progress: 1 })
    shipment = processor.shipment
    stage = processor.stages[0]
    tiff1 = File.join(shipment.barcode_directory(shipment.barcodes[0]),
                      '00000001.tif')
    stage.add_warning Error.new('err 1', shipment.barcodes[0], tiff1)
    tiff2 = File.join(shipment.barcode_directory(shipment.barcodes[1]),
                      '00000001.tif')
    stage.add_warning Error.new('err 2', shipment.barcodes[1], tiff2)
    tool = QueryTool.new(processor)
    out, _err = capture_io do
      tool.warnings_cmd
    end
    assert_match tiff1, out, 'reports warnings for both files'
    assert_match shipment.barcodes[0], out, 'reports warnings for both barcodes'
    assert_match tiff2, out, 'reports warnings for both files'
    assert_match shipment.barcodes[1], out, 'reports warnings for both barcodes'
    out, _err = capture_io do
      tool.warnings_cmd shipment.barcodes[0]
    end
    assert_match tiff1, out, 'reports warning for first file'
    assert_match shipment.barcodes[0], out, 'reports warning for first barcode'
    refute_match tiff2, out, 'no warning for second file'
    refute_match shipment.barcodes[1], out, 'no warning for second barcode'
  end

  def test_fixity_cmd # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_shipment = TestShipment.new(test_name, 'BC T contone 2-3')
    processor = Processor.new(test_shipment.directory, { no_progress: 1 })
    shipment = processor.shipment
    shipment.setup_source_directory
    shipment.checksum_source_directory
    barcode = shipment.barcodes[0]
    # Add 00000001.tif, change 00000002.tif, and remove 00000003.tif
    tiff1 = File.join(shipment.source_directory, barcode, '00000001.tif')
    refute File.exist?(tiff1), '(make sure 00000001.tif does not exist)'
    `/bin/echo -n 'test' > #{tiff1}`
    tiff2 = File.join(shipment.source_directory, barcode, '00000002.tif')
    `/bin/echo -n 'test' > #{tiff2}`
    tiff3 = File.join(shipment.source_directory, barcode, '00000003.tif')
    FileUtils.rm tiff3
    tool = QueryTool.new(processor)
    out, _err = capture_io do
      tool.fixity_cmd
    end
    out = out.decolorize
    assert_match "Added\n  #{File.join(barcode, '00000001.tif')}",
                 out, '00000001.tif added'
    assert_match "Changed\n  #{File.join(barcode, '00000002.tif')}",
                 out, '00000002.tif changed'
    assert_match "Removed\n  #{File.join(barcode, '00000003.tif')}",
                 out, '00000003.tif removed'
  end
end
