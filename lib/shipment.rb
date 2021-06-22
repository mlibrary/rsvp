#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'json'

ImageFile = Struct.new(:barcode, :path, :barcode_file, :file)

# Shipment directory class
class Shipment # rubocop:disable Metrics/ClassLength
  attr_reader :metadata

  def self.json_create(hash)
    new hash['data']['dir'], hash['data']['metadata']
  end

  def initialize(dir, metadata = nil)
    raise 'nil dir passed to Shipment#initialize' if dir.nil?

    @dir = dir
    @metadata = metadata || {}
    @metadata.transform_keys!(&:to_sym)
  end

  def to_json(*args)
    {
      'json_class' => self.class.name,
      'data' => { dir: @dir, metadata: @metadata }
    }.to_json(*args)
  end

  def status_file
    File.join(@dir, 'status.json')
  end

  def status_file?
    File.exist? status_file
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
    barcodes.map { |b| barcode_directory b }
  end

  def barcodes
    bars = Dir.entries(@dir).reject do |b|
      %w[. .. source tmp].include? b
    end
    bars.select { |b| File.directory?(barcode_directory(b)) }.sort
  end

  def barcode_directory(barcode)
    File.join(@dir, barcode)
  end

  def source_barcode_directories
    source_barcodes.map { |b| File.join(@dir, b) }
  end

  def source_barcodes
    bars = Dir.entries(source_directory).reject do |b|
      %w[. ..].include? b
    end
    bars.select { |b| File.directory?(File.join(source_directory, b)) }.sort
  end

  def source_barcode_directory(barcode)
    File.join(source_directory, barcode)
  end

  def barcode_from_path(path)
    path.split(File::SEPARATOR)[-2]
  end

  def barcode_file_from_path(path)
    path.split(File::SEPARATOR)[-2..].join(File::SEPARATOR)
  end

  def image_files(type = 'tif')
    files = []
    barcodes.each do |b|
      barcode_dir = barcode_directory b
      entries = Dir.entries(barcode_dir).reject { |e| %w[. ..].include? e }
      entries.sort.each do |e|
        next unless e.end_with? type

        files << ImageFile.new(b, File.join(barcode_dir, e), File.join(b, e), e)
      end
    end
    files
  end

  def source_image_files(type = 'tif') # rubocop:disable Metrics/AbcSize
    files = []
    return files unless File.directory? source_directory

    source_barcodes.each do |b|
      dir = File.join(source_directory, b)
      Dir.entries(dir).reject { |e| %w[. ..].include? e }.sort.each do |e|
        next unless e.end_with? type

        files << ImageFile.new(b, File.join(dir, e), File.join(b, e), e)
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

  # Copy clean or remediated barcode directories from source.
  # Called with nil to replaces all barcodes, or an Array of barcodes.
  def restore_from_source_directory(barcode_array = nil)
    unless File.directory? source_directory
      raise Errno::ENOENT, "source directory #{source_directory} not found"
    end

    barcode_array = source_barcodes if barcode_array.nil?
    barcode_array.each do |barcode|
      yield barcode if block_given?
      dest = barcode_directory barcode
      FileUtils.rm_r(dest, force: true) if File.exist? dest
      FileUtils.copy_entry(File.join(source_directory, barcode), dest)
    end
  end

  def delete_source_directory
    return unless File.exist? source_directory

    FileUtils.rm_r(source_directory, force: true)
  end

  ### === METADATA METHODS === ###
  def checksums
    metadata[:checksums] || {}
  end

  def checksum(image_file)
    Digest::SHA256.file(image_file.path).hexdigest
  end

  # Add SHA256 entries to metadata for each source/barcode/file.
  # If a block is passed, calls it one for each barcode in the source directory.
  # Must be called after #setup_source_directory.
  def checksum_source_directory
    metadata[:checksums] = {}
    last_barcode = nil
    source_image_files.each do |image_file|
      if block_given? && last_barcode != image_file.barcode
        yield image_file.barcode
      end
      metadata[:checksums][image_file.barcode_file] = checksum(image_file)
      last_barcode = image_file.barcode
    end
  end

  # Returns Hash with keys {added, changed, removed} -> Array of ImageFile
  def fixity_check # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    fixity = { added: [], removed: [], changed: [] }
    return fixity if metadata[:checksums].nil?

    source_image_files.each do |image_file|
      yield image_file if block_given?
      if checksums[image_file.barcode_file].nil?
        fixity[:added] << image_file
      elsif checksums[image_file.barcode_file] != checksum(image_file)
        fixity[:changed] << image_file
      end
    end

    checksums.keys.sort.each do |barcode_file|
      image_file = ImageFile.new(barcode_from_path(barcode_file),
                                 File.join(source_directory, barcode_file),
                                 barcode_file,
                                 barcode_file.split(File::SEPARATOR)[-1])
      yield image_file if block_given?
      fixity[:removed] << image_file unless File.exist? image_file.path
    end
    fixity
  end
end
