#!/usr/bin/env ruby
# frozen_string_literal: true

require 'command'
require 'stage'
require 'tiff'

# TIFF Validation Stage
class TIFFValidator < Stage
  BITONAL_RES = 600
  CONTONE_RES = 400

  def run(agenda)
    return unless agenda.any?

    files = image_files.select { |file| agenda.include? file.barcode }
    @bar.steps = files.count
    files.each do |image_file|
      @bar.next! image_file.barcode_file
      tiffinfo = run_tiffinfo image_file
      next if tiffinfo.nil?

      evaluate image_file, tiffinfo
    end
  end

  private

  # Run tiffinfo command and return output text block
  def run_tiffinfo(image_file) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    begin
      info = TIFF.new(image_file.path).info
    rescue StandardError => e
      add_error Error.new(e.message, image_file.barcode, image_file.file)
      return nil
    end
    log info[:cmd], info[:time]
    info[:warnings].each do |err|
      add_warning Error.new(err, image_file.barcode, image_file.file)
    end
    info[:errors].each do |err|
      add_error Error.new(err, image_file.barcode, image_file.file)
    end
    info
  end

  # Resolution line must have 'pixels/inch' unit
  # 'Bits/Sample' line -> bps
  # 'Samples/Pixel' line -> spp
  # bps of 1 requires spp=1 and xres=BITONAL_RES and yres=BITONAL_RES
  # bps of 8 requires spp in [1,3,4] and xres=CONTONE_RES and yres=CONTONE_RES
  def evaluate(image_file, info) # rubocop:disable Metrics/MethodLength
    if info[:res_unit] != 'pixels/inch'
      image_error image_file, "must have pixels/inch, not #{info[:res_unit]}"
    end
    case info[:bps]
    when 1
      evaluate_1_bps(image_file, info)
    when 8
      evaluate_8_bps(image_file, info)
    else
      image_error image_file, "can't have BPS #{info[:bps]}"
    end
  end

  def evaluate_1_bps(image_file, info)
    if info[:spp] != 1
      image_error image_file, "invalid SPP #{info[:spp]} with 1 BPS"
    end
    return unless info[:x_res] != BITONAL_RES || info[:y_res] != BITONAL_RES

    image_error image_file, "#{info[:x_res]}x#{info[:y_res]} bitonal"
  end

  def evaluate_8_bps(image_file, info)
    if [1, 3, 4].include? info[:spp]
      if info[:x_res] != CONTONE_RES || info[:y_res] != CONTONE_RES
        image_error image_file, "#{info[:x_res]}x#{info[:y_res]} contone"
      end
    else
      image_error image_file, "can't have SPP #{info[:spp]} with 8 BPS"
    end
  end

  def image_error(image_file, err)
    add_error Error.new(err, image_file.barcode, image_file.path)
  end
end
