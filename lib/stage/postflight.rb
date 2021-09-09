#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'set'

require 'jhove'
require 'stage'

# Image Metadata Validation Stage
class Postflight < Stage
  def run(agenda)
    @bar.steps = steps agenda
    agenda.each do |barcode|
      @bar.next! "validate #{barcode}"
      run_jhove barcode
    end
    @bar.next! 'barcode check'
    check_barcode_lists
    @bar.next! 'verify checksums'
    verify_source_checksums
  end

  private

  def steps(agenda)
    agenda.count + 2 +
      shipment.source_image_files.count +
      shipment.checksums.keys.count
  end

  def check_barcode_lists # rubocop:disable Metrics/AbcSize
    s1 = Set.new shipment.metadata[:initial_barcodes]
    s2 = Set.new shipment.barcodes
    if (s1 - s2).any?
      add_error Error.new("barcodes removed: #{(s1 - s2).to_a.join(', ')}")
    end
    return unless (s2 - s1).any?

    add_error Error.new("barcodes added: #{(s2 - s1).to_a.join(', ')}")
  end

  def verify_source_checksums # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    fixity = shipment.fixity_check do |image_file|
      @bar.next! image_file.barcode_file
    end
    fixity[:added].each do |image_file|
      add_error Error.new('SHA missing', image_file.barcode, image_file.file)
    end
    fixity[:removed].each do |image_file|
      add_error Error.new('file missing', image_file.barcode, image_file.file)
    end
    fixity[:changed].each do |image_file|
      add_error Error.new('SHA modified', image_file.barcode, image_file.file)
    end
  end

  def run_jhove(barcode)
    jhove = JHOVE.new(shipment.barcode_directory(barcode), config)
    begin
      jhove.run
    rescue StandardError => e
      add_error Error.new(e.message, barcode)
    end
    jhove.errors.each do |err|
      add_error JHOVE.error_object(err)
    end
  end
end
