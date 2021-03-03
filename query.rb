#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'

APP_ROOT = File.expand_path(__dir__)
$LOAD_PATH << File.join(APP_ROOT, 'lib')
require 'string_color'
require 'processor'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options] DIR [DIR...]"

  opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
    options[:verbose] = v
  end

  if ARGV.empty?
    puts opts.help
    exit 1
  end
end.parse!

ARGV.each do |dir|
  dir = Pathname.new(dir).cleanpath.to_s
  unless File.exist?(dir) && File.directory?(dir)
    puts "Shipment directory #{dir.bold} does not exist, skipping".red
    next
  end
  unless File.exist?(File.join(dir, 'status.json'))
    puts "No status.json found in #{dir.bold}, skipping".red
    next
  end
  begin
    processor = Processor.new(dir, options)
  rescue JSON::ParserError => e
    puts "unable to parse #{File.join(dir, status.json)}: #{e}"
    next
  end
  processor.query
end
