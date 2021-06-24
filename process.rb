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
opts.banner = "Usage: #{$PROGRAM_NAME} [options] DIR"
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

ARGV.each do |arg|
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
  end
  begin
    puts "Processing #{dir}...".blue
    processor.run
    tool = QueryTool.new processor
  rescue Interrupt
    puts "\nInterrupted".red
  ensure
    processor.finalize
    processor.write_status_file
    tool.status_cmd
  end
end
