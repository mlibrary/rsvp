#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

# Processing error class
class Error
  include Comparable
  attr_reader :barcode, :path, :description

  def self.json_create(hash)
    new hash['data']['description'], hash['data']['barcode'],
        hash['data']['path']
  end

  def initialize(description, barcode = nil, path = nil)
    raise 'nil description passed to Error#initialize' if description.nil?

    @description = description
    @barcode = barcode
    @path = path
  end

  def <=>(other)
    return nil unless other.is_a?(self.class)

    [@barcode || '', @path || '', @description] <=>
      [other.barcode || '', other.path || '', other.description]
  end

  def to_s
    format '%<description>s%<barcode>s%<path>s',
           description: @description,
           barcode: (@barcode.nil? ? '' : " #{@barcode}"),
           path: (@path.nil? ? '' : " #{@path}")
  end

  def to_json(*args)
    {
      'json_class' => self.class.name,
      'data' => { description: @description, barcode: @barcode, path: @path }
    }.to_json(*args)
  end
end
