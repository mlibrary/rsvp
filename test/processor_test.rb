#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'processor'

class ProcessorTest < Minitest::Test
  def teardown
    TestShipment.remove_test_shipments
  end

  def test_new # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment = TestShipment.new(test_name, '')
    processor = Processor.new(shipment.dir, {})
    refute_nil processor, 'processor successfully created'
    refute_nil processor.status, 'processor status exists'
    refute File.exist?(File.join(shipment.dir, 'status.json')),
           'status.json not created yet'
    processor.write_status
    assert File.exist?(File.join(shipment.dir, 'status.json')),
           'status.json created'
    metadata = processor.status[:metadata]
    assert metadata, 'processor metadata initialized'
  end

  def test_config
    shipment = TestShipment.new(test_name, '')
    options = { config_dir: File.join(TEST_ROOT, 'config') }
    processor = Processor.new(shipment.dir, options)
    refute_nil processor, 'processor successfully created'
    assert_match(/fake_feed_validate/, processor.config[:feed_validate_script],
                 'has custom feed validate path')
  end

  def test_unlink_status_on_reset
    shipment = TestShipment.new(test_name, '')
    status_json = File.join(shipment.dir, 'status.json')
    FileUtils.touch(status_json)
    options = { restart_all: 1 }
    Processor.new(shipment.dir, options)
    refute File.exist?(status_json), 'status.json deleted on reset'
  end

  def test_stages
    shipment = TestShipment.new(test_name, '')
    processor = Processor.new(shipment.dir)
    assert_kind_of Array, processor.stages, 'processor#stages is Array'
  end

  def test_query
    shipment = TestShipment.new(test_name, '')
    processor = Processor.new(shipment.dir)
    assert_output(/not.yet.run/i) { processor.query }
  end

  def test_run # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment = TestShipment.new(test_name, 'BC F .DS_Store')
    options = { no_progress: true }
    processor = Processor.new(shipment.dir, options)
    capture_io do
      processor.run
    end
    assert_kind_of Hash, processor.status
    refute_nil processor.status[:stages]
    stage = processor.status[:stages][:Preflight]
    refute_nil stage
    refute_nil stage[:start]
    refute_nil stage[:end]
    assert_predicate stage[:errors].select { |i| i[/no.TIFF/i] }, :any?,
                     'Preflight fails with no TIFFs error'
    assert_predicate stage[:warnings].select { |i| i[/\.DS_Store/] }, :any?,
                     'Preflight warns about .DS_Store'
  end

  def test_invalid_status_file
    shipment = TestShipment.new(test_name, 'BC F .DS_Store')
    status_json = File.join(shipment.dir, 'status.json')
    FileUtils.touch(status_json)
    assert_raises(JSON::ParserError) { Processor.new(shipment.dir, {}) }
    assert_equal(File.size(status_json), 0, 'status.json is unmodified')
  end

  def test_discard_failure
    spec = 'BC T bad_16bps 1'
    shipment = TestShipment.new(test_name, spec)
    processor = Processor.new(shipment.dir, {})
    capture_io do
      processor.run
    end
    keys_before = processor.status[:stages].keys.count
    processor.send :discard_failure
    keys_after = processor.status[:stages].keys.count
    assert(keys_after < keys_before, 'discard_errors removes failing stage')
  end

  def test_report_stage_error_long
    shipment = TestShipment.new(test_name, 'BC T bad_16bps 1-20')
    processor = Processor.new(shipment.dir, {})
    out, _err = capture_io do
      processor.run
    end
    assert_match(/and\s\d+\smore/, out, 'long stage error report truncated')
    out, _err = capture_io do
      processor.query
    end
    refute_match(/and\s\d+\smore/, out, 'long stage error report from query')
  end
end
