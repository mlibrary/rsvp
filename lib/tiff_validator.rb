#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'stage'

# TIFF Validation Stage
class TIFFValidator < Stage
  BITONAL_RES = '600'
  CONTONE_RES = '400'

  def run
    cmd = "find #{@dir} -name '*.tif' -type f | sort"
    files = `#{cmd}`.split("\n")
    files.each_with_index do |file, i|
      write_progress(i, files.count,
                     file.split(File::SEPARATOR)[-2..-1].join(File::SEPARATOR))
      fields = extract_tiff_fields(run_tiffinfo(file))
      err = evaluate(file, fields)
      @errors << err unless err.nil?
    end
    write_progress(files.count, files.count)
  end

  private

  # Run tiffinfo command and return output text block
  def run_tiffinfo(path) # rubocop:disable Metrics/MethodLength
    cmd = "tiffinfo #{path}"
    stdout_str, stderr_str, code = Open3.capture3(cmd)
    @errors << "'#{cmd}' exited with status #{code}" if code.exitstatus != 0
    if code != 0
      @errors << "Command '#{cmd}' exited with status #{code.exitstatus}"
    end
    stderr_str.chomp.split("\n").each do |err|
      if /tag\signored/.match? err
        @warnings << "#{path}: #{err}"
      else
        @errors << "#{path}: #{err}"
      end
    end
    stdout_str
  end

  # Resolution line must have 'pixels/inch' unit
  # 'Bits/Sample' line -> bps
  # 'Samples/Pixel' line -> spp
  # bps of 1 requires spp=1 and xres=BITONAL_RES and yres=BITONAL_RES
  # bps of 8 requires spp in [1,3,4] and xres=CONTONE_RES and yres=CONTONE_RES
  def evaluate(file, info) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity
    if info[:res_unit] != 'pixels/inch'
      return "#{file} must have pixels/inch resolution, not #{info[:res_unit]}"
    end

    case info[:bps]
    when '1'
      if info[:spp] != '1'
        return "#{file}\tCan't have SPP #{info[:spp]} with 1 BPS"
      end

      if info[:xres] != BITONAL_RES || info[:yres] != BITONAL_RES
        "#{file}\t#{info[:xres]}x#{info[:yres]} bitonal"
      end
    when '8'
      if %w[1 3 4].include? info[:spp]
        if info[:xres] != CONTONE_RES || info[:yres] != CONTONE_RES
          "#{file}\t#{info[:xres]}x#{info[:yres]} contone"
        end
      else
        "#{file}\tCan't have SPP #{info[:spp]} with BPS 8"
      end
    else
      "#{file}\tCan't have BPS #{info[:bps]}"
    end
  end

  # Return Hash with fields xres, yres, res_unit, bps, spp
  def extract_tiff_fields(info)
    h = {}
    m = info.match(/Resolution:\s(\d+(?:\.\d+)?),\s*(\d+(?:\.\d+)?)\s+(.*)/)
    h[:xres] = m[1]
    h[:yres] = m[2]
    h[:res_unit] = m[3]
    m = info.match(%r{Bits/Sample:\s(\d+)})
    h[:bps] = m[1]
    m = info.match(%r{Samples/Pixel:\s(\d+)})
    h[:spp] = m[1]
    h
  end
end
