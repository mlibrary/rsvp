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
    shipment.metadata[:initial_barcodes] = shipment.objids
    if shipment.metadata[:initial_barcodes].none?
      add_error Error.new("no objids in #{shipment_directory}")
    end
    @bar.steps = steps agenda
    @bar.next! "validate #{File.split(shipment_directory)[-1]}"
    validate_shipment_directory
    shipment.setup_source_directory do |objid|
      @bar.next! "setup source/#{objid}"
    end
    shipment.checksum_source_directory do |objid|
      @bar.next! "checksum source/#{objid}"
    end
    agenda.each do |objid|
      err = shipment.validate_objid objid
      add_warning Error.new(err, objid) unless err.nil?
      @bar.next! "validate #{objid}"
      validate_objid_directory objid
    end
  end

  private

  def steps(agenda)
    1 + shipment.objids.count + agenda.count +
      (File.directory?(source_directory) ? 0 : shipment.objids.count)
  end

  # A shipment directory is valid if it contains only objid directories,
  # a source directory, and status.json
  def validate_shipment_directory # rubocop:disable Metrics/MethodLength
    Dir.entries(shipment_directory).sort.each do |entry|
      next if %w[. .. source tmp status.json].include? entry

      path = File.join(shipment_directory, entry)
      next if File.directory? path

      if self.class.removable_files.include? entry
        add_warning Error.new('unnecessary file deleted', nil, path)
        delete_on_success path
      else
        add_error Error.new('unknown file', nil, path)
      end
    end
  end

  # objid directory must include one or more TIFF files,
  # and a few other exceptions grandfathered by just_do_everything.sh
  # No directories are allowed
  def validate_objid_directory(objid) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    have_tiff = false
    objid_directory = shipment.objid_directory(objid)
    Dir.entries(objid_directory).sort.each do |entry|
      next if %w[. ..].include? entry

      path = File.join(objid_directory, entry)
      if File.directory? path
        add_error Error.new("illegal objid subdirectory '#{entry}'", objid)
      elsif self.class::TIFF_REGEX.match? entry
        have_tiff = true
      elsif self.class.ignorable_files.include? entry
        add_warning Error.new('file ignored', objid, entry)
      elsif self.class.removable_files.include? entry
        add_warning Error.new('file deleted', objid, entry)
        delete_on_success path
      else
        add_error Error.new('unknown file', objid, entry)
      end
    end
    add_error Error.new('no TIFF files found', objid) unless have_tiff
  end
end
