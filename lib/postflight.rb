#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'set'
require 'stage'

# Image Metadata Validation Stage
class Postflight < Stage
  def run
    process_shipment_directory
  end

  private

  def process_shipment_directory # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    real_barcodes = []
    barcode_directories.each_with_index do |path, i|
      barcode = path.split(File::SEPARATOR)[-1]
      write_progress(i, barcode_directories.count + 2,
                     "feed validate #{barcode}")
      if File.directory? path
        process_barcode_directory(path, barcode)
        real_barcodes << barcode
      end
    end
    write_progress(barcode_directories.count, barcode_directories.count + 2,
                   'barcode check')
    check_barcode_lists(real_barcodes)
    write_progress(barcode_directories.count + 1, barcode_directories.count + 2,
                   'verify checksums')
    verify_source_checksums
    write_progress(barcode_directories.count + 2, barcode_directories.count + 2)
  end

  def process_barcode_directory(dir, barcode)
    script = @options[:config][:feed_validate_script]
    cmd = "perl #{script} google mdp #{dir} #{barcode}"
    log "running '#{cmd}'"
    run_command(cmd)
  end

  def check_barcode_lists(barcodes)
    s1 = Set.new @metadata[:barcodes]
    s2 = Set.new barcodes
    @errors << "barcodes removed during run: #{s1 - s2}" if (s1 - s2).any?
    @errors << "barcodes added during run: #{s2 - s1}" if (s2 - s1).any?
  end

  def verify_source_checksums # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    @shipment.source_image_files.each do |path|
      if @metadata[:checksums][path].nil?
        @errors << "file added: no checksum for #{path}"
      else
        sha256 = Digest::SHA256.file path
        if @metadata[:checksums][path] != sha256.hexdigest
          @errors << "checksum mismatch: #{path} changed" \
                     " from #{@metadata[:checksums][path]}" \
                     " to #{sha256.hexdigest}"
        end
      end
    end
    @metadata[:checksums].each_key do |path|
      unless File.exist? path
        @errors << "file missing: #{path} not found in source directory"
      end
    end
  end

  def run_command(cmd)
    stdout_str, _stderr_str, code = Open3.capture3(cmd)
    @errors << "'#{cmd}' returned #{code.exitstatus}" if code.exitstatus != 0
    return unless stdout_str.chomp.length.positive?

    err_lines = stdout_str.chomp.split("\n")
    err_lines.each do |line|
      next if line == 'failure!' && @errors.any?
      next if line == 'success!'

      @errors << line
    end
  end
end
