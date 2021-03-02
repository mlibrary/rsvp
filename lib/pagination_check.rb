#!/usr/bin/env ruby
# frozen_string_literal: true

require 'stage'

# Pagination Stage
class PaginationCheck < Stage
  def run
    @re = /^([0-9]{8})\.(?:tif|jp2)$/
    barcodes = Dir.entries(@dir).sort.delete_if { |e| %w[. ..].include? e }
    barcodes.each do |barcode|
      path = File.join(@dir, barcode)
      find_errors_in_dir(path) if File.directory? path
    end
  end

  private

  def find_errors_in_dir(dir)
    pages = pages_in_dir(dir)
    missing = missing_pages(pages)
    if missing.count.positive?
      @errors << "#{dir}: missing pages {#{missing.join(', ')}}"
    end
    duplicate = duplicate_pages(pages)
    return unless duplicate.count.positive?

    @errors << "#{dir}: duplicate pages {#{duplicate.join(', ')}}"
  end

  def pages_in_dir(dir)
    entries = Dir.entries(dir)
    pages = []
    entries.each do |entry|
      match = entry.match @re
      pages << match[1].to_i if match
    end
    pages.sort
  end

  # Given sorted pages array of integers from 1 to n inclusive,
  # returns array of integer and integer range strings missing from list
  def missing_pages(pages) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    missing = (1..pages.max).to_a - pages
    ranges = []
    missing.each do |m|
      if ranges[-1].class == Integer && ranges[-1] == m - 1
        ranges[-1] = [ranges[-1], m]
      elsif ranges[-1].class == Array && ranges[-1][-1] == m - 1
        ranges[-1] << m
      else
        ranges << m
      end
    end
    ranges.map { |r| r.class == Array ? "#{r[0]}-#{r[-1]}" : r.to_s }
  end

  # Given sorted pages array of integers from 1 to n inclusive,
  # returns array of integer strings duplicated in pages
  def duplicate_pages(pages)
    dups = {}
    pages.each_with_index do |val, idx|
      (dups[val] ||= []) << idx
    end
    dups.delete_if { |_k, v| v.size == 1 }
    dups.keys.map(&:to_s)
  end
end
