#!/usr/bin/env ruby
# frozen_string_literal: true

# Shipment directory class
class Shipment
  attr_reader :metadata

  def initialize(dir)
    raise 'nil dir passed to Shipment#initialize' if dir.nil?

    @dir = dir
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
    @barcode_directories ||= barcodes.map { |b| File.join(@dir, b) }
  end

  def barcodes
    @barcodes ||= begin
      bars = Dir.entries(@dir).reject { |b| %w[. .. source tmp].include? b }
      bars.select { |b| File.directory?(File.join(@dir, b)) }
    end
  end

  def source_barcode_directories
    @source_barcode_directories ||= source_barcodes.map do |b|
      File.join(@dir, b)
    end
  end

  def source_barcodes
    @source_barcodes ||= begin
      bars = Dir.entries(source_directory).reject do |b|
        %w[. .. source tmp].include? b
      end
      bars.select { |b| File.directory?(File.join(@dir, b)) }
    end
  end

  def barcode_from_path(path)
    path.split(File::SEPARATOR)[-2]
  end

  def barcode_file_from_path(path)
    path.split(File::SEPARATOR)[-2..-1].join(File::SEPARATOR)
  end

  def image_files(type = 'tif')
    cmd = "find #{@dir} -name '*.#{type}' -type f -print" \
          " -o \\( -path #{source_directory} -prune \\) | sort"
    `#{cmd}`.split("\n")
  end

  def source_image_files(type = 'tif')
    cmd = "find #{source_directory} -name '*.#{type}' -type f -print | sort"
    `#{cmd}`.split("\n")
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
      if File.directory? dir
        dest = File.join(source_directory, dir.split(File::SEPARATOR)[-1])
        FileUtils.copy_entry(dir, dest)
      end
    end
  end

  def restore_from_source_directory(*barcode_list)
    unless File.directory? source_directory
      raise Errno::ENOENT, "source directory #{source_directory} not found"
    end

    barcode_list = source_barcodes if barcode_list.size.zero?
    barcode_list.each do |barcode|
      dest = File.join(@dir, barcode)
      FileUtils.rm_r(dest, force: true) if File.exist? dest
      FileUtils.copy_entry(File.join(source_directory, barcode), dest)
    end
  end
end
