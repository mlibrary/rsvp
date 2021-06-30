#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'stage'

# TIFF Validation Stage
class TIFFValidator < Stage
  BITONAL_RES = '600'
  CONTONE_RES = '400'

  def run(agenda) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return unless agenda.any?

    files = image_files.select { |file| agenda.include? file.barcode }
    @bar.steps = files.count
    files.each do |image_file|
      @bar.next! image_file.barcode_file
      tiffinfo = run_tiffinfo(image_file)
      next if tiffinfo.nil?

      fields = extract_tiff_fields tiffinfo
      err = evaluate fields
      unless err.nil?
        add_error Error.new(err, image_file.barcode, image_file.file)
      end
    end
  end

  private

  # Run tiffinfo command and return output text block
  def run_tiffinfo(image_file) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    cmd = "tiffinfo #{image_file.path}"
    stdout_str, stderr_str, code = Open3.capture3(cmd)
    if code.exitstatus != 0
      add_error Error.new("'#{cmd}' exited with status #{code.exitstatus}",
                          image_file.barcode, image_file.path)
    end
    stderr_str.chomp.split("\n").each do |err|
      if /warning/i.match? err
        add_warning Error.new(err, image_file.barcode, image_file.file)
      else
        add_error Error.new(err, image_file.barcode, image_file.file)
        return nil
      end
    end
    stdout_str
  end

  # Resolution line must have 'pixels/inch' unit
  # 'Bits/Sample' line -> bps
  # 'Samples/Pixel' line -> spp
  # bps of 1 requires spp=1 and xres=BITONAL_RES and yres=BITONAL_RES
  # bps of 8 requires spp in [1,3,4] and xres=CONTONE_RES and yres=CONTONE_RES
  def evaluate(info) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity
    if info[:res_unit] != 'pixels/inch'
      return "must have pixels/inch resolution, not #{info[:res_unit]}"
    end

    case info[:bps]
    when '1'
      return "can't have SPP #{info[:spp]} with 1 BPS" if info[:spp] != '1'

      if info[:xres] != BITONAL_RES || info[:yres] != BITONAL_RES
        "#{info[:xres]}x#{info[:yres]} bitonal"
      end
    when '8'
      if %w[1 3 4].include? info[:spp]
        if info[:xres] != CONTONE_RES || info[:yres] != CONTONE_RES
          "#{info[:xres]}x#{info[:yres]} contone"
        end
      else
        "can't have SPP #{info[:spp]} with 8 BPS"
      end
    else
      "can't have BPS #{info[:bps]}"
    end
  end

  # Return Hash with fields xres, yres, res_unit, bps, spp
  def extract_tiff_fields(info) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    h = {}
    m = info.match(/Resolution:\s(\d+(?:\.\d+)?),\s*(\d+(?:\.\d+)?)\s+(.*)/)
    unless m.nil?
      h[:xres] = m[1]
      h[:yres] = m[2]
      h[:res_unit] = m[3]
    end
    m = info.match(%r{Bits/Sample:\s(\d+)})
    h[:bps] = m[1] unless m.nil?
    m = info.match(%r{Samples/Pixel:\s(\d+)})
    h[:spp] = m[1] unless m.nil?
    h
  end
end
