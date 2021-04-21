#!/usr/bin/env ruby
# frozen_string_literal: true

require 'stage'
require 'tag_data'

# TIFF Metadata update stage
# The only thing that is required here is that the artist tag for 'dcu'
# is applied to all files that don't have it.
class Tagger < Stage
  def run # rubocop:disable Metrics/AbcSize
    @barcode_to_tempdir = {}
    calculate_tags
    return if errors.count.positive?

    image_files.each_with_index do |image_file, i|
      write_progress(i, image_files.count, image_file.barcode_file)
      tag image_file
    end
    write_progress(image_files.count, image_files.count)
    cleanup
  end

  private

  def calculate_tags # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    artist = @options[:tagger_artist] || 'dcu'
    @artist_tag ||= if TagData::ARTIST[artist].nil?
                      add_warning Error.new("using custom artist '#{artist}'")
                      artist
                    else
                      TagData::ARTIST[artist]
                    end
    scanner = @options[:tagger_scanner]
    unless scanner.nil?
      if TagData::SCANNER[scanner].nil?
        unless /\|/.match? scanner
          add_error Error.new("user-defined scanner not in 'make|model' format")
          return
        end

        add_warning Error.new("using custom scanner '#{scanner}'")
        @make_tag, @model_tag = scanner.split('|')
      else
        @make_tag, @model_tag = TagData::SCANNER[scanner]
      end
    end
    software = @options[:tagger_software]
    return if software.nil?

    if TagData::SOFTWARE[software].nil?
      add_warning Error.new("using custom software '#{software}'")
      @software_tag = software
    else
      @software_tag = TagData::SOFTWARE[software]
    end
  end

  def tag(image_file) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    tagged_name = image_file.path.split(File::SEPARATOR)[-1] + '.tagged'
    tagged_path = File.join(tempdir_for_file(image_file), tagged_name)
    tagged = ImageFile.new(image_file.barcode, tagged_path,
                           File.join(image_file.barcode,
                                     image_file.path + '.tagged'))
    FileUtils.cp(image_file.path, tagged_path)
    copy_on_success(tagged_path, image_file.path)
    tag_artist tagged
    tag_scanner tagged
    tag_software tagged
    run_tiffset(tagged, 274, '1')
  end

  def tag_artist(image_file)
    run_tiffset(image_file, 315, @artist_tag) unless @artist_tag.nil?
  end

  def tag_scanner(image_file)
    run_tiffset(image_file, 271, @make_tag) unless @make_tag.nil?
    run_tiffset(image_file, 272, @model_tag) unless @model_tag.nil?
  end

  def tag_software(image_file)
    run_tiffset(image_file, 305, @software_tag) unless @software_tag.nil?
  end

  def tempdir_for_file(image_file)
    if @barcode_to_tempdir.key? image_file.barcode
      return @barcode_to_tempdir[image_file.barcode]
    end

    dir = create_tempdir
    @barcode_to_tempdir[image_file] = dir
    dir
  end

  def run_tiffset(image_file, tag, value) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    cmd = "tiffset -s #{tag} '#{value}' #{image_file.path}"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      add_error Error.new("'#{cmd}': exited with status #{code}",
                          image_file.barcode, image_file.path)
    end
    stderr_str.chomp.split("\n").each do |err|
      if /tag\signored/.match? err
        add_warning Error.new("#{cmd}: #{err}", image_file.barcode,
                              image_file.path)
      else
        add_error Error.new("#{cmd}: #{err}", image_file.barcode,
                            image_file.path)
        next
      end
    end
  end
end
