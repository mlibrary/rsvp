#!/usr/bin/env ruby
# frozen_string_literal: true

require 'tempfile'

require 'config'
require 'error'
require 'progress_bar'

# Base class for conversion stages
class Stage
  attr_reader :data, :config
  attr_accessor :name, :shipment

  def initialize(shipment, config = nil) # rubocop:disable Metrics/MethodLength
    unless shipment.is_a? Shipment
      raise StandardError,
            "shipment class #{shipment.class} for #{self.class}#initialize"
    end

    @name = self.class.to_s
    @config = config || Config.new
    @shipment = shipment
    # FIXME: change this back to @errors when tests are passing,
    # maybe restore attr_reader
    @errs = [] # Fatal conditions, Array of Error
    @warns = [] # Nonfatal conditions, Array of Error
    @data = {} # A data structure that is written to status.json for the stage
    @bar = ProgressBar.new(self.class, config)
  end

  def run
    raise "#{self.class.name}.run() method unimplemented"
  end

  def add_error(err)
    raise "nil err passed to #{self.class}#add_error" if err.nil?
    raise "#{err.class} passed to add_error" unless err.is_a? Error

    @bar.error = true
    @errs << err
  end

  def add_warning(err)
    raise "nil err passed to #{self.class}#add_warning" if err.nil?
    raise "#{err.class} passed to add_warning" unless err.is_a? Error

    @warns << err
  end

  def errors
    @errs
  end

  def warnings
    @warns
  end

  # OK to make destructive changes to the shipment
  # FIXME: rename make_changes_to_barcode?
  def make_changes?
    @errs.none? && !config[:noop]
  end

  # Expected to be run as part of #run,
  # may be called multiple times.
  def cleanup
    @bar.done!
    cleanup_copy_on_success
    cleanup_delete_on_success
    cleanup_tempdirs
  end

  def cleanup_copy_on_success
    return if @copy_on_success.nil?

    while @copy_on_success.any?
      pair = @copy_on_success.pop
      FileUtils.cp pair[0], pair[1] if make_changes?
    end
  end

  def cleanup_delete_on_success
    return if @delete_on_success.nil? || !make_changes?

    FileUtils.rm @delete_on_success.pop while @delete_on_success.any?
  end

  def cleanup_tempdirs
    return if @tempdirs.nil?

    FileUtils.rm_rf @tempdirs.pop while @tempdirs.any?
    return unless File.directory? shipment.tmp_directory

    FileUtils.rm_rf shipment.tmp_directory
  end

  def create_tempdir
    unless File.directory? shipment.tmp_directory
      Dir.mkdir shipment.tmp_directory
    end
    (@tempdirs ||= []) << Dir.mktmpdir(nil, shipment.tmp_directory)
    @tempdirs[-1]
  end

  # source is copied to destination on success,
  # left alone on failure or if noop option flag is set.
  def copy_on_success(source, destination)
    (@copy_on_success ||= []) << [source, destination]
  end

  def delete_on_success(path)
    (@delete_on_success ||= []) << path
  end

  def barcode_from_path(path)
    shipment.barcode_from_path(path)
  end

  def barcode_file_from_path(path)
    shipment.barcode_file_from_path(path)
  end

  def log(entry)
    (@data[:log] ||= []) << entry
  end

  def shipment_directory
    shipment.directory
  end

  def source_directory
    shipment.source_directory
  end

  def barcode_directories
    shipment.barcode_directories
  end

  def image_files(type = 'tif')
    shipment.image_files(type)
  end
end
