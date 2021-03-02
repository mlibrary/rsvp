#!/usr/bin/env ruby
# frozen_string_literal: true

require 'luhn'
require 'fixtures'

class TestShipment
  attr_reader :barcodes

  PATH = File.join(__dir__, 'shipments').freeze
  @test_shipments = []

  def self.remove_test_shipments
    while @test_shipments.any?
      dir = File.join(PATH, @test_shipments.pop)
      FileUtils.rm_r(dir, force: true)
    end
  end

  def self.add_test_shipment(name)
    Dir.mkdir PATH unless File.exist? PATH
    @test_shipments << name
  end

  # Randomly-generated barcode that passes Luhn check
  def self.generate_barcode(valid = true)
    barcode = '39015' + (8.times.map { rand 10 }).join
    if valid
      barcode + Luhn.checksum(barcode).to_s
    else
      barcode + ((Luhn.checksum(barcode) + 1) % 10).to_s
    end
  end

  # Generate a test directory under test/shipments based on specification
  # spec is a string of opcodes and optional parameters
  # OPCODES
  # [BC] create barcode directory (and make it current)
  # [BBC] create bogus barcode directory (and make it current)
  # [TIF name, dest] copy TIF fixture to dest (which can be a range)
  # [F dest] create zero-length file at dest
  # [DIR] cwd to shipment directory
  def initialize(name, spec)
    self.class.add_test_shipment(name)
    @barcodes = []
    @name = name
    FileUtils.rm_r(dir, force: true) if File.directory? dir
    Dir.mkdir(dir)
    process_spec spec
  end

  def process_spec(spec) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    @current_dir = dir
    elements = spec.split(/\s+/)
    while elements.any?
      op = elements.shift
      case op
      when 'BC'
        handle_barcode_op
      when 'BBC'
        handle_bogus_barcode_op
      when 'T'
        handle_tiff_op(elements.shift, elements.shift)
      when 'J'
        handle_jp2_op(elements.shift, elements.shift)
      when 'F'
        FileUtils.touch(File.join(@current_dir, elements.shift))
      when 'DIR'
        @current_dir = dir
      else
        raise "Unrecognized opcode #{op}"
      end
    end
  end

  def dir
    @dir ||= File.join(PATH, @name)
  end

  private

  def handle_barcode_op
    @barcodes << self.class.generate_barcode(true)
    @current_dir = File.join(dir, @barcodes[-1])
    Dir.mkdir(@current_dir)
  end

  def handle_bogus_barcode_op
    @barcodes << self.class.generate_barcode(false)
    @current_dir = File.join(dir, @barcodes[-1])
    Dir.mkdir(@current_dir)
  end

  def handle_tiff_op(name, dest) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    fixture = Fixtures.tiff_fixture(name)
    case dest
    when /^\d+$/
      dest = format '%<filename>08d.tif', { filename: dest }
      FileUtils.cp fixture, File.join(@current_dir, dest)
    when /^\d+-\d+$/
      first, last = dest.split('-').map(&:to_i)
      raise "Ill-formed TIFF file range #{match[1]}-#{match[2]}" if first > last

      (first..last).each do |n|
        dest = format '%<filename>08d.tif', { filename: n }
        FileUtils.cp fixture, File.join(@current_dir, dest)
      end
    else
      raise "Unknown TIFF destination format '#{dest}'"
    end
  end

  def handle_jp2_op(name, dest) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    fixture = Fixtures.jp2_fixture(name)
    case dest
    when /^\d+$/
      dest = format '%<filename>08d.jp2', { filename: dest }
      FileUtils.cp fixture, File.join(@current_dir, dest)
    when /^\d+-\d+$/
      first, last = dest.split('-').map(&:to_i)
      raise "Ill-formed JP2 file range #{match[1]}-#{match[2]}" if first > last

      (first..last).each do |n|
        dest = format '%<filename>08d.jp2', { filename: n }
        FileUtils.cp fixture, File.join(@current_dir, dest)
      end
    else
      raise "Unknown JP2 destination format '#{dest}'"
    end
  end
end
