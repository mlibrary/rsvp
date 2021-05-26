#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'open3'
require 'set'
require 'stage'

# Image Metadata Validation Stage
class Postflight < Stage
  def run
    @bar.steps = steps
    shipment.barcodes.each do |b|
      @bar.next! "validate #{b}"
      run_feed_validate_script(b)
    end
    @bar.next! 'barcode check'
    check_barcode_lists
    @bar.next! 'verify checksums'
    verify_source_checksums
    cleanup
  end

  private

  def steps
    barcode_directories.count + 1 +
      shipment.source_image_files.count +
      shipment.metadata[:checksums].keys.count
  end

  def check_barcode_lists # rubocop:disable Metrics/AbcSize
    s1 = Set.new shipment.metadata[:initial_barcodes]
    s2 = Set.new shipment.barcodes
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

  def feed_validate_script(barcode)
    script = config[:feed_validate_script]
    dir = File.join(shipment.directory, barcode)
    "perl #{script} google mdp #{dir} #{barcode}"
  end

  def run_feed_validate_script(barcode)
    cmd = feed_validate_script barcode
    log "running '#{cmd}'"
    stdout_str, stderr_str, code = Open3.capture3(cmd)
    if code.exitstatus.zero?
      process_feed_validate_output(barcode, stdout_str)
    else
      msg = "'#{cmd}' returned #{code.exitstatus}: #{stderr_str}"
      add_error Error.new(msg, barcode)
    end
  end

  def process_feed_validate_output(barcode, output)
    return if output.chomp.length.zero?

    err_lines = output.chomp.split("\n")
    err_lines.each do |line|
      next if line == 'failure!' && err_lines.count > 1
      next if line == 'success!'

      process_feed_validate_line barcode, line
    end
  end

  def process_feed_validate_line(barcode, line)
    # Remove ANSI color and leading runtime info and pid
    line = line.decolorize.sub(/.+?(?=(ERROR|WARN))/, '')
    fields = line.split("\t")
    # Extract file if possible, nil if no match
    file = line[/\tfile: (.*?)(\t|$)/, 1]
    file = File.join(barcode, file) unless file.nil?
    # Remove fields starting with "objid: ", "namespace: ", "remediable: ",
    # "stage: ", and "file: "
    re = /^(objid|namespace|remediable|stage|file): /
    fields = fields.delete_if { |f| re.match? f }
    desc = fields.join ', '
    # Compact "Invalid value for field, field:" errors
    desc = desc.gsub(/Invalid value for field, field:/i,
                     'invalid value for field')
    add_feed_validate_error(desc, barcode, file)
  end

  def add_feed_validate_error(desc, barcode, file)
    if /^warn - /i.match? desc
      desc = desc.gsub(/^warn - /i, '')
      add_warning Error.new(desc, barcode, file)
    else
      desc = desc.gsub(/^error - /i, '')
      unless /file validation failed/i.match?(desc) && !file.nil? &&
             errors.any? { |e| e.barcode == barcode && e.path == file }
        add_error Error.new(desc, barcode, file)
      end
    end
  end
end
