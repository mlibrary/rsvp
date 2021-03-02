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
      process_file(file)
    end
    write_progress(files.count, files.count)
    cleanup
  end

  private

  def process_file(path)
    fields = extract_tiff_fields(run_tiffinfo(path))
    return unless fields[:artist].to_s == '' || fields[:orientation].to_s == ''

    tag path
  end

  # Return Hash with fields software, artist, make, model
  def extract_tiff_fields(info)
    h = {}
    { software: /Software:\s(.*)/,
      artist: /Artist:\s(.*)/,
      make: /Make:\s(.*)/,
      model: /Model:\s(.*)/,
      orientation: /Orientation:\s(.*)/ }.each do |k, v|
      m = info.match(v)
      h[k] = m[1] unless m.nil?
    end
    h
  end

  # Sets artist and orientation if they are not already set.
  def tag(path)
    tagged = File.join(tempdir_for_file(path), File.basename(path) + '.tagged')
    FileUtils.cp(path, tagged)
    copy_on_success tagged, path
    tags = [%w[274 1],
            ['315', TagData::ARTIST['dcu']]]
    tags.each do |t|
      run_tiffset(tagged, t[0], t[1])
    end
  end

  def tempdir_for_file(path)
    barcode = barcode_from_file(path)
    return @barcode_to_tempdir[barcode] if @barcode_to_tempdir.key? barcode

    dir = create_tempdir
    @barcode_to_tempdir[barcode] = dir
    dir
  end

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
