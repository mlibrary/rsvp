#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'set'
require 'stage'

# Image Metadata Validation Stage
class Postflight < Stage
  def run(agenda = shipment.barcodes)
    process_shipment_directory agenda
  end

  private

  def process_shipment_directory(agenda) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    real_barcodes = []
    barcode_directories.each_with_index do |path, i|
      barcode = path.split(File::SEPARATOR)[-1]
      real_barcodes << barcode
      unless agenda.include? barcode
        write_progress(i, barcode_directories.count, "#{barcode} skipped")
        next
      end
      write_progress(i, barcode_directories.count + 2,
                     "feed validate #{barcode}")
      process_barcode_directory(path, barcode)
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
