#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'tempfile'
require 'time'

require 'config'
require 'error'
require 'progress_bar'
require 'symbolize'

# Base class for conversion stages
class Stage # rubocop:disable Metrics/ClassLength
  attr_reader :errors, :warnings, :start, :end
  attr_accessor :name, :config, :shipment

  def self.json_create(hash)
    data = Symbolize.symbolize hash['data']
    new nil, **data
  end

  def to_json(*args)
    {
      'json_class' => self.class.name,
      'data' => { name: @name,
                  errors: @errors,
                  warnings: @warnings,
                  data: @data,
                  start: @start.to_s,
                  end: @end.to_s }
    }.to_json(*args)
  end

  # Can be created without a shipment, but that field needs to be set
  # before the #run method can be called.
  def initialize(shipment, **args) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    unless shipment.nil? || shipment.is_a?(Shipment)
      raise StandardError, "unknown shipment class #{shipment.class}"
    end

    @shipment = shipment
    @name = args[:name] || self.class.to_s
    @config = args[:config] || {} # Top-level Config object
    @errors = args[:errors] || [] # Fatal conditions, Array of Error
    @warnings = args[:warnings] || [] # Nonfatal conditions, Array of Error
    @data = args[:data] || {} # Misc data structure including log
    # Time the stage was last run (may be unneeded)
    @start = if args[:start].to_s == ''
               nil
             else
               Time.parse args[:start]
             end
    # Time the stage last finished running (may be unneeded)
    # Currently used by #complete?
    @end = if args[:end].to_s == ''
             nil
           else
             Time.parse args[:end]
           end
    @bar = if config[:no_progress]
             SilentProgressBar.new(self.class)
           else
             ProgressBar.new(self.class)
           end
  end

  # Get rid of errors, warnings, and anything that may have been memoized
  def reinitialize!
    @errors = []
    @warnings = []
    @bar.done = 0
  end

  def run!(agenda = nil)
    @start = Time.now
    agenda = shipment.barcodes if agenda.nil?
    @bar.steps = agenda.count
    run agenda
    cleanup
    @end = Time.now
  end

  # This is the method that needs to be implemented by a subclass
  def run(_agenda)
    raise "#{self.class.name}#run method unimplemented"
  end

  def add_error(err)
    raise "#{err.class} passed to add_error" unless err.is_a? Error
    unless err.barcode.nil? || barcodes.member?(err.barcode)
      raise "unknown error barcode #{err.barcode}"
    end

    @bar.error = true
    @errors << err
  end

  def add_warning(err)
    raise "#{err.class} passed to add_warning" unless err.is_a? Error
    unless err.barcode.nil? || barcodes.member?(err.barcode)
      raise "unknown warning barcode #{err.barcode}"
    end

    @bar.warning = true
    @warnings << err
  end

  # Map of barcodes + nil -> [Errors]
  # Does not include barcodes with no errors
  def errors_by_barcode
    errors.each_with_object({}) do |err, memo|
      (memo[err.barcode] ||= []) << err
    end
  end

  # Map of barcodes + nil -> [Errors]
  # Does not include barcodes with no warnings
  def warnings_by_barcode
    warnings.each_with_object({}) do |err, memo|
      (memo[err.barcode] ||= []) << err
    end
  end

  def error_barcodes
    errors_by_barcode.keys.compact
  end

  # Any error with barcode == nil is fatal.
  def fatal_error?
    errors_by_barcode.key? nil
  end

  def delete_errors_for_barcode(barcode)
    @errors.delete_if { |e| e.barcode == barcode }
  end

  def delete_warnings_for_barcode(barcode)
    @warnings.delete_if { |w| w.barcode == barcode }
  end

  # OK to make destructive changes to the shipment for this barcode?
  # With nil barcode checks for presence of any error.
  def make_changes?(barcode = nil)
    return @errors.none? if barcode.nil?

    @errors.none? { |e| e.barcode == barcode || e.barcode.nil? }
  end

  # True if the stage has been run and all possible errors have
  # had a chance to surface
  def complete?
    @errors.none? && !@end.nil?
  end

  # Expected to be run as part of #run,
  # may be called multiple times.
  def cleanup(interrupt = false)
    cleanup_copy_on_success
    cleanup_delete_on_success
    cleanup_tempdirs
    @bar.done! unless interrupt
  end

  def cleanup_copy_on_success
    return if @copy_on_success.nil?

    while @copy_on_success.any?
      copy = @copy_on_success.pop
      if make_changes? copy[:barcode]
        FileUtils.cp copy[:source], copy[:destination]
      end
    end
  end

  def cleanup_delete_on_success
    return if @delete_on_success.nil? || !make_changes?

    @delete_on_success.each do |del|
      FileUtils.rm del[:path] if make_changes? del[:barcode]
    end
    @delete_on_success = nil
  end

  def cleanup_tempdirs
    unless @tempdirs.nil? # ruboccop:disable Style/IfUnlessModifier
      FileUtils.rm_rf @tempdirs.pop while @tempdirs.any?
    end
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
  # left alone on failure.
  def copy_on_success(source, destination, barcode)
    (@copy_on_success ||= []) << { source: source, destination: destination,
                                   barcode: barcode }
  end

  def delete_on_success(path, barcode = nil)
    (@delete_on_success ||= []) << { path: path, barcode: barcode }
  end

  def barcodes
    shipment.barcodes
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
