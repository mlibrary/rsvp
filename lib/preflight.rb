#!/usr/bin/env ruby
# frozen_string_literal: true

require 'luhn'
require 'stage'

# Shipment directory well-formedness and content check.
# The only changes this stage makes to the filesystem is deletion
# of Thumbs.db and .DS_Store
class Preflight < Stage
  def self.removable_files
    %w[.DS_Store Thumbs.db]
  end

  def self.ignorable_files
    %w[aiim.tif aiim.jp2 notes.txt rit.tif
       checksum.md5 prodnote.tif]
  end

  def initialize(dir, metadata, options)
    super
    @metadata[:barcodes] = []
    @tiff_regex = /^\d{8}\.tif$/
  end

  def run # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    validate_shipment_directory
    @errors << "no barcode directories in #{@dir}" if @metadata[:barcodes].none?
    @metadata[:barcodes].each_with_index do |barcode, i|
      unless Luhn.valid? barcode
        @warnings << "Luhn checksum failed for barcode #{barcode}"
      end
      write_progress(i, @metadata[:barcodes].count, barcode)
      validate_barcode_directory File.join(@dir, barcode)
    end
    write_progress(@metadata[:barcodes].count, @metadata[:barcodes].count)
    cleanup
  end

  private

  # A shipment directory is valid if it contains only barcode directories
  # and status.json
  def validate_shipment_directory # rubocop:disable Metrics/MethodLength
    Dir.entries(@dir).sort.each do |entry|
      next if %w[. ..].include? entry
      next if entry == 'status.json'

      path = File.join(@dir, entry)
      if File.directory? path
        @metadata[:barcodes] << entry
      elsif self.class.removable_files.include? entry
        @warnings << "#{path} deleted"
        delete_on_success path
      else
        @errors << "unknown file #{path}"
      end
    end
  end

  # Barcode directory must include one or more TIFF files,
  # and a few other exceptions grandfathered by just_do_everything.sh
  # No directories are allowed
  def validate_barcode_directory(dir) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    have_tiff = false
    Dir.entries(dir).sort.each do |entry|
      next if %w[. ..].include? entry

      path = File.join(dir, entry)
      if File.directory? path
        @errors << "subdirectory '#{entry}' found in barcode directory #{dir}"
      elsif @tiff_regex.match? entry
        have_tiff = true
      elsif self.class.ignorable_files.include? entry
        @warnings << "#{path} ignored"
      elsif self.class.removable_files.include? entry
        @warnings << "#{path} deleted"
        delete_on_success path
      else
        @errors << "unknown file #{path}"
      end
    end
    @errors << "no TIFF files in barcode directory #{dir}" unless have_tiff
  end
end
