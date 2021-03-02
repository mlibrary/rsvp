#!/usr/bin/env ruby
# frozen_string_literal: true

APP_ROOT = File.expand_path('..', __dir__)
TEST_ROOT = File.expand_path(__dir__)
$LOAD_PATH << File.join(APP_ROOT, 'lib')
$LOAD_PATH << TEST_ROOT

require 'minitest'
require 'simplecov'
require 'test_shipment'

SimpleCov.start do
  add_filter do |file|
    (/_test\.rb$/.match? File.basename(file.filename))
  end
end

module Minitest
  class Test
    def test_name
      [self.class.to_s, caller_locations(1..1)[0].label].join '_'
    end
  end
end
