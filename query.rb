#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'
require 'optparse'
require 'readline'

APP_ROOT = File.expand_path(__dir__)
$LOAD_PATH << File.join(APP_ROOT, 'lib')
require 'string_color'
require 'processor'

options_data = [['-c', '--config-dir', :config_dir,
                 'Directory for configuration files'],
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

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options] DIR [DIR...]"

  options_data.each do |vals|
    opts.on(vals[0], vals[1], vals[3]) do |v|
      options[vals[2]] = v
    end
  end

  if ARGV.count != 1
    puts opts.help
    exit 1
  end
end.parse!

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

commands = ['barcodes', 'errors', 'exit', 'help', 'ls', 'metadata', 'quit',
            'run', 'status', '?']

completions = commands + processor.shipment.barcodes
Readline.completion_append_character = ' '
Readline.completion_proc = proc do |str|
  completions.grep(/^#{Regexp.escape(str)}/)
end

command_summary = <<~COMMANDS
  COMMAND            SUMMARY                 ALIAS
  ==============================================================
  barcodes           List shipment barcodes  ls
  errors [BARCODE]   List shipment errors
  help               Print this message      ?
  metadata           Show metadata summary
  quit               Quit the program        exit
  run                Run processor
  status             Query shipment status
  warnings [BARCODE] List shipment warnings
  ==============================================================
COMMANDS

prompt = '> '
begin
  while (line = Readline.readline(prompt, true).rstrip)
    cmd, *args = line.split
    begin
      case cmd
      when 'agenda'
        processor.stages.each do |stage|
          puts stage.name.bold
          processor.agenda[stage.name].each do |barcode|
            puts "  #{barcode}".bold
          end
        end
      when 'barcodes', 'ls'
        processor.shipment.barcodes.each do |b|
          puts b.bold
        end
      when 'errors'
        processor.error_query.each_key do |barcode|
          next if args.count.positive? && !args.include?(barcode)

          puts (barcode.nil? ? '(General)' : barcode).bold
          processor.error_query[barcode].each do |h|
            puts h[:stage].brown
            h[:errors].each do |err|
              puts "  #{'File'.bold}\t#{err.path}" unless err.path.nil?
              puts "  #{'Error'.bold}\t#{err.description.italic}"
            end
          end
        end
      when 'help', '?'
        puts command_summary
      when 'metadata'
        puts processor.metadata_query.brown
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
        processor.warning_query.each_key do |barcode|
          next if args.count.positive? && !args.include?(barcode)

          puts (barcode.nil? ? '(General)' : barcode).bold
          processor.warning_query[barcode].each do |h|
            puts h[:stage].brown
            h[:warnings].each do |warn|
              puts "  #{'File'.bold}\t#{warn.path}" unless warn.path.nil?
              puts "  #{'Error'.bold}\t#{warn.description.italic}"
            end
          end
        end
      else
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
