#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'luhn'
require 'stage'

# Shipment directory well-formedness and content check.
# The only changes this stage makes to the filesystem is deletion
# of Thumbs.db and .DS_Store
class Preflight < Stage
  TIFF_REGEX = /^\d{8}\.tif$/.freeze

  def self.removable_files
    %w[.DS_Store Thumbs.db]
  end

  def self.ignorable_files
    %w[aiim.tif aiim.jp2 notes.txt rit.tif
       checksum.md5 prodnote.tif]
  end

  def run(agenda) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment.metadata[:initial_barcodes] = []
    @bar.steps = steps agenda
    @bar.next! "validate #{shipment_directory}"
    validate_shipment_directory
    if shipment.metadata[:initial_barcodes].none?
      add_error Error.new("no barcode directories in #{shipment_directory}")
      return
    end
    shipment.setup_source_directory do |barcode|
      @bar.next! "setup source/#{barcode}"
    end
    shipment.checksum_source_directory do |barcode|
      @bar.next! "checksum source/#{barcode}"
    end
    agenda.each do |barcode|
      unless Luhn.valid? barcode
        add_warning Error.new('Luhn checksum failed', barcode)
      end
      @bar.next! "validate #{barcode}"
      validate_barcode_directory barcode
    end
  end

  private

  def steps(agenda)
    1 + shipment.barcodes.count + agenda.count +
      (File.directory?(source_directory) ? 0 : shipment.barcodes.count)
  end

  # A shipment directory is valid if it contains only barcode directories,
  # a source directory, and status.json
  def validate_shipment_directory # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    Dir.entries(shipment_directory).sort.each do |entry|
      next if %w[. .. source tmp status.json].include? entry

      path = File.join(shipment_directory, entry)
      next if entry == 'source' && File.directory?(path)

      if File.directory? path
        shipment.metadata[:initial_barcodes] << entry
      elsif self.class.removable_files.include? entry
        add_warning Error.new("#{path} deleted")
        delete_on_success path
      else
        add_error Error.new("unknown file #{path}")
      end
    end
  end

  # Barcode directory must include one or more TIFF files,
  # and a few other exceptions grandfathered by just_do_everything.sh
  # No directories are allowed
  def validate_barcode_directory(barcode) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    have_tiff = false
    Dir.entries(File.join(shipment_directory, barcode)).sort.each do |entry|
      next if %w[. ..].include? entry

      path = File.join(shipment_directory, barcode, entry)
      if File.directory? path
        add_error Error.new("illegal barcode subdirectory '#{entry}'", barcode)
      elsif self.class::TIFF_REGEX.match? entry
        have_tiff = true
      elsif self.class.ignorable_files.include? entry
        add_warning Error.new('file ignored', barcode, path)
      elsif self.class.removable_files.include? entry
        add_warning Error.new('file deleted', barcode, path)
        delete_on_success path
      else
        add_error Error.new('unknown file', barcode, path)
      end
    end
    add_error Error.new('no TIFF files found', barcode) unless have_tiff
  end
end
