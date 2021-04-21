#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'stage'

JP2_LEVEL_MIN = 5
JP2_LAYERS = 8
JP2_ORDER = 'RLCP'
JP2_USE_SOP = 'yes'
JP2_USE_EPH = 'yes'
JP2_MODES = '"RESET|RESTART|CAUSAL|ERTERM|SEGMARK"'
JP2_SLOPE = 42_988

TIFF_DATE_FORMAT = '%Y:%m:%d %H:%M:%S'

# Internal class for errors arising from external binaries
class CompressorError < StandardError
  def initialize(msg, command = '', detail = '')
    super "#{self.class}: #{msg} (#{command}) (#{detail})"
  end
end

# TIFF to JP2/TIFF compression stage
class Compressor < Stage # rubocop:disable Metrics/ClassLength
  def run # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    image_files.each_with_index do |image_file, i|
      metadata = tiffinfo(image_file)
      next if metadata.nil?

      # Figure out what sort of image this is.
      m = metadata.match(%r{Bits/Sample:\s(\d+)})
      bps = m[1].to_i
      case bps
      when 8
        # It's a contone, so we convert to JP2.
        write_progress(i, image_files.count, "#{image_file.barcode_file} JP2")
        begin
          handle_8_bps_conversion(image_file.path, metadata)
        rescue CompressorError => e
          add_error Error.new(e.message, image_file.barcode, image_file.path)
        end
      when 1
        # It's bitonal, so we G4 compress it.
        write_progress(i, image_files.count, "#{image_file.barcode_file} G4")
        begin
          handle_1_bps_conversion(image_file.path, metadata)
        rescue CompressorError => e
          add_error Error.new(e.message, image_file.barcode, image_file.path)
        end
      else
        add_error Error.new("invalid source TIFF BPS #{bps}",
                            image_file.barcode, image_file.path)
      end
    end
    write_progress(image_files.count, image_files.count)
    cleanup
  end

  private

  def tiffinfo(image_file) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    cmd = "tiffinfo #{image_file.path}"
    stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      add_error Error.new("'#{cmd}' exit status #{code.exitstatus}",
                          image_file.barcode, image_file.path)
      return nil
    end
    stderr_str.chomp.split("\n").each do |err|
      if /tag\signored/.match? err
        add_warning Error.new(err, image_file.barcode, image_file.path)
      else
        add_error Error.new(err, image_file.barcode, image_file.path)
        return nil
      end
    end
    stdout_str
  end

  def handle_8_bps_conversion(file, metadata) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    tmpdir = create_tempdir
    sparse = File.join(tmpdir, 'sparse.tif')
    new_image = File.join(tmpdir, 'new.jp2')
    final_image = File.join(File.dirname(file),
                            File.basename(file, '.*') + '.jp2')

    # We don't want any XMP metadata to be copied over on its own. If
    # it's been a while since we last ran exiftool, this might take a sec.
    remove_tiff_metadata(file, sparse)

    alpha_channel = false
    if /Extra\sSamples:\s1<unassoc-alpha>/.match? metadata
      alpha_channel = true
      remove_tiff_alpha(sparse)
    end

    strip_tiff_profiles(sparse) if /ICC\sProfile:\s<present>/.match? metadata

    # FIXME: process-tiffs.sh defines this variable but does not
    # use it. Check the original on tang.
    # if /Samples\/Pixel:\s3/.match? metadata
    #  jp2_space = 'sRGB'
    # else
    #  jp2_space = 'sLUM'
    # end

    # We have a TIFF with no XMP now. We try to convert it to JP2.
    # This will always take a second. Other than the initial loading
    # of exiftool libraries, this is the only JP2 step that takes
    # noticeable time.
    compress_jp2(sparse, new_image, metadata)
    # We have our JP2; we can remove the middle TIFF. Then we try
    # to grab metadata from the original TIFF. This should be very
    # quick since we just used exiftool a few lines back.
    copy_jp2_metadata(file, new_image, final_image, metadata)
    # If our image had an alpha channel, it'll be gone now, and
    # the XMP data needs to reflect that (previously, we were
    # taking that info from the original image).
    copy_jp2_alphaless_metadata(sparse, new_image) if alpha_channel
    copy_on_success new_image, final_image
    delete_on_success file
  end

  def jp2_clevels(metadata)
    # Get the width and height.
    m = metadata.match(/Image\sWidth:\s(\d+)\sImage\sLength:\s(\d+)/)
    # Figure out which is larger.
    size = [m[1].to_i, m[2].to_i].max
    # Calculate appropriate Clevels.
    clevels = (Math.log(size.to_i / 100.0) / Math.log(2)).to_i
    clevels < JP2_LEVEL_MIN ? JP2_LEVEL_MIN : clevels
  end

  def remove_tiff_metadata(path, destination)
    cmd = "exiftool -XMP:All= -MakerNotes:All= #{path} -o #{destination}"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise CompressorError.new('Could not extract XMP-less TIFF',
                                cmd, stderr_str)
    end
    log cmd
  end

  def remove_tiff_alpha(path)
    tmp = path + '.alphaoff'
    cmd = "convert #{path} -alpha off #{tmp}"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise CompressorError.new('Could not remove alpha channel',
                                cmd, stderr_str)
    end
    log cmd
    FileUtils.mv(tmp, path)
  end

  def strip_tiff_profiles(path)
    tmp = path + '.stripped'
    cmd = "convert #{path} -strip #{tmp}"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    if code.exitstatus.zero?
      log cmd
      FileUtils.mv(tmp, path)
    else
      warning = "couldn't remove ICC profile (#{cmd}) (#{stderr_str})"
      add_warning Error.new(warning, shipment.barcode_from_path(path), path)
    end
  end

  def compress_jp2(source, destination, metadata) # rubocop:disable Metrics/MethodLength
    clevels = jp2_clevels(metadata)
    cmd = "kdu_compress -quiet -i #{source} -o #{destination}" \
          " 'Clevels=#{clevels}'" \
          " 'Clayers=#{JP2_LAYERS}'" \
          " 'Corder=#{JP2_ORDER}'" \
          " 'Cuse_sop=#{JP2_USE_SOP}'" \
          " 'Cuse_eph=#{JP2_USE_EPH}'" \
          " Cmodes=#{JP2_MODES}" \
          " -no_weights -slope '#{JP2_SLOPE}'"
    # For testing under Docker, fall back to ImageMagick instead of Kakadu
    cmd = "convert #{source} #{destination}" if ENV['KAKADONT']
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise CompressorError.new('Could not convert to JPEG 2000',
                                cmd, stderr_str)
    end

    log cmd
  end

  def copy_jp2_metadata(source, destination, final_image, metadata) # rubocop:disable Metrics/MethodLength
    # If the original image has a date, we want it. If not, we
    # want to add the current date.
    # date "%Y-%m-%dT%H:%M:%S"
    datetime = if /DateTime:/.match? metadata
                 '-IFD0:ModifyDate>XMP-tiff:DateTime'
               else
                 "-XMP-tiff:DateTime=#{Time.now.strftime('%FT%T')}"
               end
    cmd = "exiftool -tagsFromFile #{source}"                  \
          " '-XMP-dc:source=#{final_image}'"                  \
          " '-XMP-tiff:Compression=JPEG 2000'"                \
          " '-IFD0:ImageWidth>XMP-tiff:ImageWidth'"           \
          " '-IFD0:ImageHeight>XMP-tiff:ImageHeight'"         \
          " '-IFD0:BitsPerSample>XMP-tiff:BitsPerSample'"     \
          " '-IFD0:PhotometricInterpretation>XMP-tiff:"       \
          "PhotometricInterpretation'"                        \
          " '-IFD0:Orientation>XMP-tiff:Orientation'"         \
          " '-IFD0:SamplesPerPixel>XMP-tiff:SamplesPerPixel'" \
          " '-IFD0:XResolution>XMP-tiff:XResolution'"         \
          " '-IFD0:YResolution>XMP-tiff:YResolution'"         \
          " '-IFD0:ResolutionUnit>XMP-tiff:ResolutionUnit'"   \
          " '-IFD0:Artist>XMP-tiff:Artist'"                   \
          " '-IFD0:Make>XMP-tiff:Make'"                       \
          " '-IFD0:Model>XMP-tiff:Model'"                     \
          " '-IFD0:Software>XMP-tiff:Software'"               \
          " '#{datetime}'"                                    \
          " -overwrite_original #{destination}"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise CompressorError.new('Could not copy alphaless TIFF metadata',
                                cmd, stderr_str)
    end
    log cmd
  end

  def copy_jp2_alphaless_metadata(source, destination) # rubocop:disable Metrics/MethodLength
    cmd = "exiftool -tagsFromFile #{source}" \
            " '-IFD0:BitsPerSample>XMP-tiff:BitsPerSample'"     \
            " '-IFD0:SamplesPerPixel>XMP-tiff:SamplesPerPixel'" \
            " '-IFD0:PhotometricInterpretation>XMP-tiff:"       \
            "PhotometricInterpretation'"                        \
            " -overwrite_original '#{destination}'"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise CompressorError.new('Could not copy alphaless TIFF metadata',
                                cmd, stderr_str)
    end
    log cmd
  end

  def handle_1_bps_conversion(path, metadata) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    tmpdir = create_tempdir
    compressed = File.join(tmpdir, "#{File.basename(path)}-compressed")
    page1 = File.join(tmpdir, "#{File.basename(path)}-page1")
    compress_tiff(path, compressed)
    copy_tiff_metadata(path, compressed)
    copy_tiff_page1(compressed, page1)
    FileUtils.rm(compressed)
    write_tiff_date_time page1 unless /DateTime:/.match? metadata
    write_tiff_document_name(path, page1)
    match = /Software:\s(.+)/.match metadata
    if match.nil?
      add_warning Error.new('could not extract software',
                            shipment.barcode_from_path(path), path)
    else
      write_tiff_software(page1, match[1])
    end
    copy_on_success page1, path
  end

  # Try to compress the image. This is the only part of this step
  # that should take any time. It should take a second or so.
  def compress_tiff(path, destination)
    cmd = "tifftopnm #{path} | pnmtotiff -g4 -rowsperstrip" \
          " 196136698 > #{destination}"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise CompressorError.new('failed to compress TIFF', cmd, stderr_str)
    end

    log cmd
  end

  def copy_tiff_metadata(path, destination) # rubocop:disable Metrics/MethodLength
    cmd = "exiftool -tagsFromFile #{path}"     \
          " '-IFD0:DocumentName'"              \
          " '-IFD0:ImageDescription='"         \
          " '-IFD0:Orientation'"               \
          " '-IFD0:XResolution'"               \
          " '-IFD0:YResolution'"               \
          " '-IFD0:ResolutionUnit'"            \
          " '-IFD0:ModifyDate'"                \
          " '-IFD0:Artist'"                    \
          " '-IFD0:Make'"                      \
          " '-IFD0:Model'"                     \
          " '-IFD0:Software'"                  \
          " -overwrite_original '#{destination}'"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise CompressorError.new('Could not copy TIFF metadata', cmd, stderr_str)
    end

    log cmd
  end

  def copy_tiff_page1(path, destination)
    cmd = "tiffcp #{path},0 #{destination}"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise CompressorError.new('could not copy TIFF page 1', cmd, stderr_str)
    end

    log cmd
  end

  # Set the document name with barcode/image.tif
  def write_tiff_document_name(path, destination)
    docname = barcode_file_from_path path
    cmd = "tiffset -s 269 '#{docname}' #{destination}"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise CompressorError.new('could not set 269 doc name', cmd, stderr_str)
    end

    log cmd
  end

  # Remove ImageMagick software tag (if it exists) and replace with original
  def write_tiff_software(path, software) # rubocop:disable Metrics/MethodLength
    cmd = "exiftool -IFD0:Software= -overwrite_original #{path}"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise CompressorError.new('could not remove ImageMagick software tag',
                                cmd, stderr_str)
    end
    log cmd
    cmd = "tiffset -s 305 '#{software}' #{path}"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise CompressorError.new('could not set 305 software', cmd, stderr_str)
    end

    log cmd
  end

  def write_tiff_date_time(path)
    date = Time.now.strftime(TIFF_DATE_FORMAT)
    cmd = "tiffset -s 306 '#{date}' #{path}"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      raise CompressorError.new('failed to set TIFF date', cmd, stderr_str)
    end

    log cmd
  end
end
