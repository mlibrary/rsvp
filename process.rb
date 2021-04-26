#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'pathname'
require 'json'
require 'byebug'
require 'yaml'

APP_ROOT = File.expand_path(__dir__)
$LOAD_PATH << File.join(APP_ROOT, 'lib')
require 'string_color'
require 'processor'

options_data = [['-c', '--config-dir', :config_dir,
                 'Directory for configuration files'],
                ['-n', '--noop', :noop,
                 'No-op, make no changes to the filesystem'],
                ['-r', '--reset', :reset,
                 'Reset and try last failed stage'],
                ['-R', '--restart-all', :restart_all,
                 'Discard status.json and restart all stages'],
                ['-v', '--verbose', :verbose,
                 'Run verbosely'],
                ['-1', '--one-stage', :one_stage,
                 'Run one stage and then stop'],
                [:OPTIONAL, '--tagger-scanner=SCANNER', :tagger_scanner,
                 'Set scanner tag to SCANNER'],
                [:OPTIONAL, '--tagger-software=SOFTWARE', :tagger_software,
                 'Set scan software tag to SOFTWARE'],
                [:OPTIONAL, '--tagger-artist=ARTIST', :tagger_artist,
                 'Set artist tag to ARTIST']]
options = {}
opts = OptionParser.new
opts.banner = "Usage: #{$PROGRAM_NAME} [options] DIR"
options_data.each do |vals|
  opts.on(vals[0], vals[1], vals[3]) do |v|
    options[vals[2]] = v
  end
end
opts.parse!

if ARGV.count != 1
  puts opts.help
  exit 1
end

dir = Pathname.new(ARGV[0]).realpath.to_s
unless File.exist?(dir) && File.directory?(dir)
  puts "Shipment directory #{dir.bold} does not exist".red
  exit 1
end

begin
  puts "Creating Processor with #{dir}"
  processor = Processor.new(dir, options)
rescue JSON::ParserError => e
  puts "unable to parse #{File.join(dir, status.json)}: #{e}"
  exit 1
end


ARGV.each do |dir|
  dir = Pathname.new(dir).cleanpath.to_s
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
    processor.run
  rescue Interrupt
    puts "\nInterrupted".red
  ensure
    processor.write_status
  end
end
