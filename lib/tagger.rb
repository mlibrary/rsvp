#!/usr/bin/env ruby
# frozen_string_literal: true

require 'stage'
require 'tag_data'

# TIFF Metadata update stage
# The only thing that is required here is that the artist tag for 'dcu'
# is applied to all files that don't have it.
class Tagger < Stage
  def run
    @metadata[:tags] = {}
    @barcode_to_tempdir = {}
    cmd = "find #{@dir} -name '*.tif' -type f | sort"
    files = `#{cmd}`.split("\n")
    files.each_with_index do |file, i|
      write_progress(i, files.count, file)
      tag file
    end
    write_progress(files.count, files.count)
    cleanup
  end

  private

  # Sets artist and orientation if they are not already set.
  def tag(path)
    tagged = File.join(tempdir_for_file(path), File.basename(path) + '.tagged')
    FileUtils.cp(path, tagged)
    copy_on_success(tagged, path)
    tag_artist tagged
    tag_scanner tagged
    tag_software tagged
    run_tiffset(tagged, 274, '1')
  end

  def tag_artist(path)
    artist = @options[:tagger_artist] || 'dcu'
    if TagData::ARTIST[artist].nil?
      @warnings << "using custom artist '#{artist}'"
      tag = artist
    else
      tag = TagData::ARTIST[artist]
    end
    run_tiffset(path, 315, tag)
  end

  def tag_scanner(path) # rubocop:disable Metrics/MethodLength
    scanner = @options[:tagger_scanner] || return
    if TagData::SCANNER[scanner].nil?
      unless /\|/.match? scanner
        @errors << "user-defined scanner must be pipe-delimited 'make|model'"
        return
      end

      @warnings << "using custom scanner '#{scanner}'"
      make, model = scanner.split('|')
    else
      make, model = TagData::SCANNER[scanner]
    end
    run_tiffset(path, 271, make)
    run_tiffset(path, 272, model)
  end

  def tag_software(path)
    software = @options[:tagger_software] || return
    if TagData::SOFTWARE[software].nil?
      @warnings << "using custom software '#{software}'"
      tag = software
    else
      tag = TagData::SOFTWARE[software]
    end
    run_tiffset(path, 305, tag)
  end

  def tempdir_for_file(path)
    barcode = barcode_from_file(path)
    return @barcode_to_tempdir[barcode] if @barcode_to_tempdir.key? barcode

    dir = create_tempdir
    @barcode_to_tempdir[barcode] = dir
    dir
  end

  def run_tiffset(file, tag, value) # rubocop:disable Metrics/MethodLength
    cmd = "tiffset -s #{tag} '#{value}' #{file}"
    _stdout_str, stderr_str, code = Open3.capture3(cmd)
    unless code.exitstatus.zero?
      @errors << "'#{cmd}': exited with status #{code.exitstatus}"
    end
    stderr_str.chomp.split("\n").each do |err|
      if /tag\signored/.match? err
        @warnings << "#{cmd}: #{err}"
      else
        @errors << "#{cmd}: #{err}"
        next
      end
    end
  end
end
