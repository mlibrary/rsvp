#!/usr/bin/env ruby
# frozen_string_literal: true

require 'stage'
require 'set'

# Image Metadata Validation Stage
class Postflight < Stage
  def run
    process_shipment_directory
  end

  private

  # Can we record successful conversions in @data and
  # then only redo the ones that failed?
  # process-tifs.sh seems to expect to run on shipment directory
  def process_shipment_directory # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    barcodes = Dir.entries(@dir).sort.delete_if { |e| %w[. ..].include? e }
    real_barcodes = []
    barcodes.each_with_index do |barcode, i|
      path = File.join(@dir, barcode)
      write_progress(i, barcodes.count + 1, "feed validate #{barcode}")
      if File.directory? path
        process_barcode_directory(path, barcode)
        real_barcodes << barcode
      end
    end
    write_progress(barcodes.count, barcodes.count + 1, 'barcode check')
    check_barcode_lists(real_barcodes)
    write_progress(barcodes.count + 1, barcodes.count + 1)
  end

  def process_barcode_directory(dir, barcode)
    script = @options[:config][:feed_validate_script]
    cmd = "perl #{script} google mdp #{dir} #{barcode}"
    log "running '#{cmd}'"
    run_command(cmd)
    Dir.entries(dir).each do |entry|
      next if %w[. ..].include? entry

      path = File.join(dir, entry)
      unless File.directory? path
        # run_md5(dir, entry)
      end
    end
  end

  def check_barcode_lists(barcodes)
    s1 = Set.new @metadata[:barcodes]
    s2 = Set.new barcodes
    @errors << "barcodes removed during run: #{s1 - s2}" if (s1 - s2).any?
    @errors << "barcodes added during run: #{s2 - s1}" if (s2 - s1).any?
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

  #   def run_md5(dir, entry)
  #     path = File.join(dir, entry)
  #     cmd = (/darwin/.match? RUBY_PLATFORM ? 'md5 -r ' : 'md5sum ') + path
  #     output = _run_command(cmd)
  #     @md5_data[dir] = +'' if @md5_data[dir].nil? # thawed String
  #     @md5_data[dir] << output
  #   end
end
