#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'
require 'optparse'
require 'readline'

APP_ROOT = File.expand_path(__dir__)
$LOAD_PATH << File.join(APP_ROOT, 'lib')
$LOAD_PATH << File.join(APP_ROOT, 'lib', 'stage')
require 'string_color'
require 'processor'
require 'query_tool'

options_data = [['-c', '--config-profile PROFILE', :config_profile,
                 'Configuration PROFILE (e.g., "dlxs")'],
                ['-d', '--config-dir DIRECTORY', :config_dir,
                 'Configuration directory DIRECTORY'],
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

if ARGV.count != 1
  puts opts.help
  exit 1
end

dir = Pathname.new(ARGV[0]).cleanpath.to_s
unless File.exist?(dir) && File.directory?(dir)
  puts "Shipment directory #{dir.bold} does not exist".red
  exit 1
end
begin
  processor = Processor.new(dir, options)
rescue JSON::ParserError => e
  puts "unable to parse #{File.join(dir, status.json)}: #{e}"
  exit 1
end

tool = QueryTool.new(processor)

COMMANDS = ['agenda', 'barcodes', 'errors', 'exit', 'help', 'ls', 'metadata',
            'quit', 'run', 'status', '?'].freeze
COMMAND_SUMMARY = <<~COMMANDS
  COMMAND            SUMMARY                 ALIAS
  ==============================================================
  barcodes           List shipment barcodes  ls
  errors [BARCODE]   List shipment errors
  help               Print this message      ?
  fixity             Show fixity summary
  quit               Quit the program        exit
  run                Run processor
  status             Query shipment status
  warnings [BARCODE] List shipment warnings
  ==============================================================
COMMANDS

completions = COMMANDS + processor.shipment.barcodes
Readline.completion_append_character = ' '
Readline.completion_proc = proc do |str|
  completions.grep(/^#{Regexp.escape(str)}/)
end
prompt = '> '
begin
  while (line = Readline.readline(prompt, true).rstrip)
    cmd, *args = line.split
    begin
      case cmd
      when 'agenda'
        tool.agenda_cmd
      when 'barcodes', 'ls'
        tool.barcodes_cmd
      when 'errors'
        tool.errors_cmd(*args)
      when 'help', '?'
        puts command_summary
      when 'fixity'
        tool.fixity_cmd
      when 'quit', 'exit'
        break
      when 'run'
        begin
          processor.run
        rescue Interrupt
          puts "\nInterrupted".red
        ensure
          processor.write_status
        end
      when 'status'
        processor.query
      when 'warnings'
        tool.warnings_cmd(*args)
      else
        next if cmd.nil?

        puts 'Unknown command'
      end
    rescue StandardError => e
      puts "#{e.inspect.bold}\n  #{e.backtrace.join("\n  ")}".red
    end
  end
rescue Interrupt
  puts 'Goodbye'.blue
  exit 0
end
