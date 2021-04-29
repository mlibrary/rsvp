#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'tempfile'
#require 'time'
require 'error'

# Base class for conversion stages
class Stage # rubocop:disable Metrics/ClassLength
  attr_reader :data, :errors, :warnings
  attr_accessor :name, :options, :shipment, :start, :end

  def self.default_shipment=(shipment)
    @default_shipment = shipment
  end

  def self.default_shipment
    @default_shipment
  end

  def self.json_create(hash)
    raise 'no default_shipment set' if self.class.default_shipment.nil?

    new default_shipment, hash['errors'], hash['warnings'], hash['data'],
        hash['start'], hash['end']
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

  def initialize(shipment, **args) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    unless shipment.nil? || shipment.is_a?(Shipment)
      raise StandardError, "unknown shipment class #{shipment.class}"
    end

    @shipment = shipment
    @name = args[:name] || self.class.to_s
    @options = {} # Hash of command-line arguments
    @errors = args[:errors] || [] # Fatal conditions, Array of Error
    @warnings = args[:warnings] || [] # Nonfatal conditions, Array of Error
    @data = args[:data] || {} # Misc data structure including log
    # Time the stage was last run (may be unneeded)
    @start = args[:start].nil? ? nil : Time.parse(args[:start])
    # Time the stage last finished running (may be unneeded)
    @end = args[:end].nil? ? nil : Time.parse(args[:end])
  end

  def run(_agenda)
    raise "#{self.class.name}#run method unimplemented"
  end

  def add_error(err)
    raise "nil err passed to #{self.class}#add_error" if err.nil?
    raise "#{err.class} passed to add_error" unless err.is_a? Error

    @errors << err
  end

  def add_warning(err)
    raise "nil err passed to #{self.class}#add_warning" if err.nil?
    raise "#{err.class} passed to add_warning" unless err.is_a? Error

    @warnings << err
  end

  # OK to make destructive changes to the shipment for this barcode?
  # With nil barcode checks for presence of fatal error.
  # This should be called like "if make changes? && make_changes?(barcode)"
  def make_changes?(barcode = nil)
    @errors.none? { |e| e.barcode == barcode }
  end

  # Expected to be run as part of #run,
  # may be called multiple times.
  def cleanup
    cleanup_copy_on_success
    cleanup_delete_on_success
    cleanup_tempdirs
    write_progress(0, 0) unless @progress.nil?
  end

  def cleanup_copy_on_success
    return if @copy_on_success.nil?

    while @copy_on_success.any?
      copy = @copy_on_success.pop
      if make_changes? copy[:barcode]
        FileUtils.cp copy[:source], copy[:destination]
      else
        FileUtils.rm copy[:source]
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
  # deleted on failure.
  def copy_on_success(source, destination, barcode)
    (@copy_on_success ||= []) << { source: source, destination: destination,
                                   barcode: barcode }
  end

  def delete_on_success(path, barcode)
    (@delete_on_success ||= []) << { path: path, barcode: barcode }
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

  # Write a single-line progress bar.
  # The \033[K is to erase the entire line in case a previous action string
  # might not be completely overwritten by a subsequent shorter one.
  def write_progress(finished, total, action = '') # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return if @options[:no_progress]

    progress = total.zero? ? 10 : 10 * finished / total
    block = '█'.encode('utf-8')
    bar = format '%<bar>-10s', bar: block * progress
    bar = bar.red if @errors.count.positive?
    fmt = format("\r\033[K%-16s |%s| (#{finished}/#{total}) #{action}",
                 self.class, bar)
    print fmt if @progress.nil? || @progress != fmt
    if progress >= 10
      print "\n"
      @progress = nil
    else
      @progress = fmt
    end
  end
end
