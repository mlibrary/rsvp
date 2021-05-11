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

  def process_shipment_directory # rubocop:disable Metrics/MethodLength
    real_barcodes = []
    @bar.steps = steps
    barcode_directories.each do |path|
      barcode = path.split(File::SEPARATOR)[-1]
      @bar.next! "validate #{barcode}"
      if File.directory? path
        process_barcode_directory(path, barcode)
        real_barcodes << barcode
      end
    end
    @bar.next! 'barcode check'
    check_barcode_lists(real_barcodes)
    @bar.next! 'verify checksums'
    verify_source_checksums
    cleanup
  end

  def steps
    barcode_directories.count + 1 +
      shipment.source_image_files.count +
      shipment.metadata[:checksums].keys.count
  end

  def process_barcode_directory(dir, barcode)
    script = @options[:config][:feed_validate_script]
    cmd = "perl #{script} google mdp #{dir} #{barcode}"
    log "running '#{cmd}'"
    err = run_command(cmd)
    add_error Error.new(err, barcode) unless err.nil?
  end

  def check_barcode_lists(barcodes)
    s1 = Set.new shipment.metadata[:initial_barcodes]
    s2 = Set.new barcodes
    add_error Error.new("barcodes removed: #{s1 - s2}") if (s1 - s2).any?
    add_error Error.new("barcodes added: #{s2 - s1}") if (s2 - s1).any?
  end

  def verify_source_checksums # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment.source_image_files.each do |image_file|
      checksum = shipment.metadata[:checksums][image_file.path]
      @bar.next! "#{image_file.barcode_file} checksum"
      if checksum.nil?
        add_error Error.new('SHA missing', image_file.barcode, image_file.path)
      else
        sha256 = Digest::SHA256.file image_file.path
        if checksum != sha256.hexdigest
          desc = "SHA mismatch: #{checksum} vs #{sha256.hexdigest}"
          add_error Error.new(desc, image_file.barcode, image_file.path)
        end
      end
    end
    shipment.metadata[:checksums].keys.map(&:to_s).each do |path|
      @bar.next! "#{@shipment.barcode_file_from_path(path)} existence"
      unless File.exist? path
        add_error Error.new('file missing', barcode_from_path(path), path)
      end
    end
  end

  def run_command(cmd) # rubocop:disable Metrics/MethodLength
    stdout_str, stderr_str, code = Open3.capture3(cmd)
    if code.exitstatus != 0
      return "'#{cmd}' returned #{code.exitstatus}: #{stderr_str}"
    end
    return unless stdout_str.chomp.length.positive?

    err_lines = stdout_str.chomp.split("\n")
    err_lines.each do |line|
      next if line == 'failure!' && errors.any?
      next if line == 'success!'

      return line
    end
    nil
  end
end
