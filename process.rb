#!/usr/bin/env ruby
# frozen_string_literal: true

require 'byebug'
require 'json'
require 'optparse'
require 'pathname'
require 'yaml'

APP_ROOT = File.expand_path(__dir__)
$LOAD_PATH << File.join(APP_ROOT, 'lib')
$LOAD_PATH << File.join(APP_ROOT, 'lib', 'stage')

require 'processor'
require 'query_tool'
require 'string_color'

options_data = [['-c', '--config-profile PROFILE', :config_profile,
                 'Configuration PROFILE (e.g., "dlxs")'],
                ['-d', '--config-dir DIRECTORY', :config_dir,
                 'Configuration directory DIRECTORY'],
                ['-h', '--help', :help,
                 'Display this message and exit'],
                ['-R', '--restart-all', :restart_all,
                 'Discard status.json and restart all stages'],
                ['-v', '--verbose', :verbose,
                 'Run verbosely'],
                [:OPTIONAL, '--tagger-scanner SCANNER', :tagger_scanner,
                 'Set scanner tag to SCANNER'],
                [:OPTIONAL, '--tagger-software SOFTWARE', :tagger_software,
                 'Set scan software tag to SOFTWARE'],
                [:OPTIONAL, '--tagger-artist ARTIST', :tagger_artist,
                 'Set artist tag to ARTIST']].freeze
options = {}
opts = OptionParser.new
opts.banner = "Usage: #{$PROGRAM_NAME} [options] SHIPMENT_DIRECTORY"
options_data.each do |vals|
  opts.on(vals[0], vals[1], vals[3]) do |v|
    options[vals[2]] = v
  end
end

begin
  opts.parse!
rescue OptionParser::InvalidOption => e
  puts e.message.capitalize.red
  puts opts.help
  exit 1
end

if options[:help]
  puts opts.help
  exit 0
end

if ARGV.count.zero?
  puts 'Missing required parameter SHIPMENT_DIRECTORY'.red
  puts opts.help
  exit 1
end

ARGV.each do |arg| # rubocop:disable Metrics/BlockLength
  dir = Pathname.new(arg).realpath.to_s
  unless File.exist?(dir) && File.directory?(dir)
    puts "Shipment directory #{dir.bold} does not exist, skipping".red
    next
  end
  begin
    processor = Processor.new(dir, options)
  rescue JSON::ParserError => e
    puts "unable to parse #{File.join(dir, status.json)}: #{e}"
    next
  rescue FinalizedShipmentError
    puts 'Shipment has been finalized, image masters unavailable'.red
    next
  end
  begin
    puts "Processing #{dir}...".blue
    processor.run
    processor.finalize
  rescue Interrupt
    puts "\nInterrupted".red
    next
  rescue FinalizedShipmentError
    puts 'Shipment has been finalized, image masters unavailable'.red
    next
  end
  processor.write_status_file
  tool = QueryTool.new processor
  tool.status_cmd
end
