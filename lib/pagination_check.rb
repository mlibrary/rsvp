#!/usr/bin/env ruby
# frozen_string_literal: true

require 'stage'

# Pagination Stage
class PaginationCheck < Stage
  def run
    @re = /^([0-9]{8})\.(?:tif|jp2)$/
    @bar.steps = shipment.barcodes.count
    shipment.barcodes.each do |barcode|
      @bar.next! barcode
      find_errors_in_barcode(barcode)
    end
    cleanup
  end

  private

  def find_errors_in_barcode(barcode)
    dir = File.join(shipment.directory, barcode)
    pages = pages_in_dir(dir)
    missing = missing_pages(pages)
    if missing.count.positive?
      add_error Error.new("missing pages {#{missing.join(', ')}}", barcode)
    end
    duplicate = duplicate_pages(pages)
    return unless duplicate.count.positive?

    add_error Error.new("duplicate pages {#{duplicate.join(', ')}}", barcode)
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
  def missing_pages(pages) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    missing = (1..pages.max).to_a - pages
    ranges = []
    missing.each do |m|
      if ranges[-1].instance_of?(Integer) && ranges[-1] == m - 1
        ranges[-1] = [ranges[-1], m]
      elsif ranges[-1].instance_of?(Array) && ranges[-1][-1] == m - 1
        ranges[-1] << m
      else
        ranges << m
      end
    end
    ranges.map { |r| r.instance_of?(Array) ? "#{r[0]}-#{r[-1]}" : r.to_s }
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
