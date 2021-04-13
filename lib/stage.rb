#!/usr/bin/env ruby
# frozen_string_literal: true

require 'tempfile'

# Base class for conversion stages
class Stage
  attr_reader :errors, :warnings, :data
  attr_accessor :name

  def initialize(shipment, metadata, options = {}) # rubocop:disable Metrics/MethodLength
    unless shipment.is_a? Shipment
      raise StandardError,
            "shipment class #{shipment.class} for #{self.class}#initialize"
    end
    raise "nil metadata passed to #{self.class}#initialize" if metadata.nil?
    raise "nil options passed to #{self.class}#initialize" if options.nil?

    @name = self.class.to_s
    @shipment = shipment
    @metadata = metadata # Read-write information about the shipment
    @options = options # Hash of command-line arguments
    @errors = [] # Fatal conditions
    @warnings = [] # Nonfatal conditions
    @data = {} # A data structure that is written to status.json for the stage
  end

  def run
    raise "#{self.class.name}.run() method unimplemented"
  end

  # OK to make destructive changes to the shipment
  def make_changes?
    @errors.none? && !@options[:noop]
  end

  # Expected to be run as part of #run,
  # may be called multiple times.
  def cleanup
    cleanup_copy_on_success
    cleanup_delete_on_success
    cleanup_tempdirs
  end

  def cleanup_copy_on_success
    return if @copy_on_success.nil?

    while @copy_on_success.any?
      pair = @copy_on_success.pop
      if make_changes?
        FileUtils.cp pair[0], pair[1]
      else
        FileUtils.rm pair[0]
      end
    end
  end

  def cleanup_delete_on_success
    return if @delete_on_success.nil? || !make_changes?

    FileUtils.rm @delete_on_success.pop while @delete_on_success.any?
  end

  def cleanup_tempdirs
    return if @tempdirs.nil?

    FileUtils.rm_rf @tempdirs.pop while @tempdirs.any?
    FileUtils.rm_rf @tempdir if defined? @tempdir
  end

  def create_tempdir
    unless File.directory? @shipment.tmp_directory
      Dir.mkdir @shipment.tmp_directory
    end
    (@tempdirs ||= []) << Dir.mktmpdir(nil, @shipment.tmp_directory)
    @tempdirs[-1]
  end

  # source is copied to destination on success,
  # deleted on failure or if noop option flag is set.
  def copy_on_success(source, destination)
    (@copy_on_success ||= []) << [source, destination]
  end

  def delete_on_success(path)
    (@delete_on_success ||= []) << path
  end

  def barcode_from_path(path)
    @shipment.barcode_from_path(path)
  end

  def barcode_file_from_path(path)
    @shipment.barcode_file_from_path(path)
  end

  def log(entry)
    (@data[:log] ||= []) << entry
  end

  def shipment_directory
    @shipment.directory
  end

  def source_directory
    @shipment.source_directory
  end

  def barcode_directories
    @shipment.barcode_directories
  end

  def image_files(type = 'tif')
    @shipment.image_files(type)
  end

  # Write a single-line progress bar.
  # The \033[K is to erase the entire line in case a previous action string
  # might not be completely overwritten by a subsequent shorter one.
  def write_progress(finished, total, action = '')
    return if @options[:no_progress]

    progress = 10 * finished / total
    block = '█'.encode('utf-8')
    bar = format '%<bar>-10s', bar: block * progress
    bar = bar.red if @errors.count.positive?
    printf("\r\033[K%-16s |%s| (#{finished}/#{total}) #{action}",
           self.class, bar)
    @progress = progress
    puts "\n" if @progress >= 10
  end
end
