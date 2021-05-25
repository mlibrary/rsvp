#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

ImageFile = Struct.new(:barcode, :path, :barcode_file)

# Shipment directory class
class Shipment
  attr_reader :metadata

  def self.json_create(hash)
    new hash['data']['dir'], hash['data']['metadata']
  end

  def initialize(dir, metadata = nil)
    raise 'nil dir passed to Shipment#initialize' if dir.nil?

    @dir = dir
    @metadata = metadata || {}
    # Symbolize top-level metadata keys
    @metadata.keys.each do |key| # rubocop:disable Style/HashEachMethods
      if key.is_a? String
        @metadata[key.to_sym] = @metadata[key]
        @metadata.delete key
      end
    end
  end

  def to_json(*args)
    {
      'json_class' => self.class.name,
      'data' => { dir: @dir, metadata: @metadata }
    }.to_json(*args)
  end

  def directory
    @dir
  end

  def source_directory
    @source_directory ||= File.join @dir, 'source'
  end

  def tmp_directory
    @tmp_directory ||= File.join @dir, 'tmp'
  end

  def barcode_directories
    barcodes.map { |b| File.join(@dir, b) }
  end

  def barcodes
    bars = Dir.entries(@dir).reject do |b|
      %w[. .. source tmp].include? b
    end
    bars.select { |b| File.directory?(File.join(@dir, b)) }.sort
  end

  def source_barcode_directories
    source_barcodes.map { |b| File.join(@dir, b) }
  end

  def source_barcodes
    bars = Dir.entries(source_directory).reject do |b|
      %w[. ..].include? b
    end
    bars.select { |b| File.directory?(File.join(@dir, 'source', b)) }.sort
  end

  # FIXME: these may not be used any more
  def barcode_from_path(path)
    path.split(File::SEPARATOR)[-2]
  end

  def barcode_file_from_path(path)
    path.split(File::SEPARATOR)[-2..].join(File::SEPARATOR)
  end

  # Think twice about trying to memoize this.
  # Compression will change the names of image files if not the quantity.
  def image_files(type = 'tif')
    files = []
    barcodes.each do |b|
      barcode_dir = File.join(@dir, b)
      entries = Dir.entries(barcode_dir).reject { |e| %w[. ..].include? e }
      entries.each do |e|
        next unless e.end_with? type

        files << ImageFile.new(b, File.join(barcode_dir, e), File.join(b, e))
      end
    end
    files
  end

  def source_image_files(type = 'tif')
    files = []
    source_barcodes.each do |b|
      barcode_dir = File.join(@dir, 'source', b)
      entries = Dir.entries(barcode_dir).reject { |e| %w[. ..].include? e }.sort
      entries.each do |e|
        next unless e.end_with? type

        files << ImageFile.new(b, File.join(barcode_dir, e), File.join(b, e))
      end
    end
    files
  end

  # This is the very first step of the whole workflow.
  # If there is no @dir/source directory, create it and copy
  # every other directory in @dir into it.
  # We will potentially remove and re-copy directories from source/
  # but that depends on the options passed to the processor.
  def setup_source_directory
    return if File.exist? source_directory

    Dir.mkdir File.join(@dir, 'source')
    barcode_directories.each do |dir|
      next unless File.directory? dir

      barcode = dir.split(File::SEPARATOR)[-1]
      yield barcode if block_given?
      FileUtils.copy_entry(dir, File.join(source_directory, barcode))
    end
  end

  def restore_from_source_directory(*barcode_list) # rubocop:disable Metrics/AbcSize
    unless File.directory? source_directory
      raise Errno::ENOENT, "source directory #{source_directory} not found"
    end

    barcode_list = source_barcodes if barcode_list.size.zero?
    barcode_list.each do |barcode|
      yield barcode if block_given?
      dest = File.join(@dir, barcode)
      FileUtils.rm_r(dest, force: true) if File.exist? dest
      FileUtils.copy_entry(File.join(source_directory, barcode), dest)
    end
  end
end
