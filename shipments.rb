#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'
require 'optparse'

APP_ROOT = File.expand_path(__dir__)
$LOAD_PATH << File.join(APP_ROOT, 'lib')
$LOAD_PATH << File.join(APP_ROOT, 'lib/stage')
require 'string_color'
require 'processor'

options_data = [['-c', '--config-profile PROFILE', :config_profile,
                 'Configuration PROFILE (e.g., "dlxs")'],
                ['-d', '--config-dir DIRECTORY', :config_dir,
                 'Configuration directory DIRECTORY']].freeze
options = {}
opts = OptionParser.new
opts.banner = "Usage: #{$PROGRAM_NAME} [options] DIR [DIR...]"
options_data.each do |vals|
  opts.on(vals[0], vals[1], vals[3]) do |v|
    options[vals[2]] = v
  end
end
opts.parse!

if ARGV.count.zero?
  puts opts.help
  exit 1
end

# Map of path to string
statuses = {}

ARGV.each do |arg|
  dir = Pathname.new(arg).cleanpath.to_s
  unless File.exist? dir
    statuses[arg] = 'No such directory'.red
    next
  end
  unless File.directory? dir
    statuses[arg] = 'Not a directory'.red
    next
  end
  shipment = Shipment.new(dir)
  if shipment.status_file?
    begin
      processor = Processor.new(shipment, options)
      statuses[arg] = processor.errors.none? ? 'OK'.green : 'ERRORS'.red
    rescue JSON::ParserError => e
      statuses[arg] = "Can't parse #{shipment.status_file}: #{e}".red
    end
  else
    statuses[arg] = 'Not a shipment'.red
  end
end

statuses.each do |path, status|
  puts "#{status.bold} #{path}"
end
