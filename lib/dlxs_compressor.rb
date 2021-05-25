#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'stage'

# Internal class for errors arising from external binaries
class DLXSCompressorError < StandardError
  def initialize(msg, command = '', detail = '')
    super "#{self.class}: #{msg} (#{command}) (#{detail})"
  end
end

# JP2-to-TIFF conversion stage for DLXS
class DLXSCompressor < Stage
  def run # rubocop:disable Metrics/MethodLength
    files = image_files('jp2')
    @bar.steps = files.count
    files.each_with_index do |image_file, i|
      @bar.step! i, image_file.barcode_file
      begin
        handle_conversion(image_file.path)
      rescue DLXSCompressorError => e
        add_error Error.new(e.message, image_file.barcode, image_file.path)
      end
    end
    cleanup
  end

  private

  def handle_conversion(path) # rubocop:disable Metrics/MethodLength
    tmpdir = create_tempdir
    contone = File.join(tmpdir, 'contone.tif')
    bitonal = File.join(tmpdir, 'bitonal.tif')
    final_image = File.join(File.dirname(path),
                            File.basename(path, '.*') + '.tif')
    expand_jp2(path, contone)
    convert_to_tiff contone, bitonal
    FileUtils.rm contone
    copy_on_success bitonal, final_image
    copy_on_success path, jp2_name(path)
    delete_on_success path
  end

  # Expand existing jp2 into tif in temp directory
  def expand_jp2(src, dest)
    cmd = "kdu_expand -i '#{src}' -o '#{dest}'"
    # For testing under Docker, fall back to ImageMagick instead of Kakadu
    cmd = "convert #{src} #{dest}" if ENV['KAKADONT']
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise DLXSCompressorError.new('Could not expand JPEG 2000',
                                    cmd, stderr_str)
    end
    log cmd
  end

  def convert_to_tiff(src, dest)
    cmd = "convert '#{src}' -colorspace Gray -threshold '50%' \
          -compress group4 '#{dest}'"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise DLXSCompressorError.new('Could not threshold JPEG 2000',
                                    cmd, stderr_str)
    end
    log cmd
  end

  # Replace first leading zero with 'p'
  def jp2_name(path)
    File.join(File.dirname(path), File.basename(path).sub(/^\d/, 'p'))
  end
end
