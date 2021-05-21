#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'
require 'optparse'
require 'readline'

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

  if ARGV.empty? || ARGV.count > 1
    puts opts.help
    exit 1
  end
end.parse!

dir = Pathname.new(ARGV[0]).cleanpath.to_s
unless File.exist?(dir) && File.directory?(dir)
  puts "Shipment directory #{dir.bold} does not exist, skipping".red
  exit
end
unless File.exist?(File.join(dir, 'status.json'))
  puts "No status.json found in #{dir.bold}, skipping".red
  exit
end
begin
  processor = Processor.new(dir, options)
rescue JSON::ParserError => e
  puts "unable to parse #{File.join(dir, status.json)}: #{e}"
  exit
end

commands = ['barcodes', 'errors', 'exit', 'help', 'ls', 'metadata', 'quit',
            'ruby', 'status', '?']
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
              puts "#{(err.path || '').bold} #{err.description.italic}"
            end
          end
        end
      when 'help', '?'
        puts command_summary
      when 'metadata'
        puts processor.metadata_query.brown
      when 'quit', 'exit'
        break
      when 'status'
        processor.query
      when 'warnings'
        processor.warning_query.each_key do |barcode|
          next if args.count.positive? && !args.include?(barcode)

          puts (barcode.nil? ? '(General)' : barcode).bold
          processor.warning_query[barcode].each do |h|
            puts h[:stage].brown
            h[:warnings].each do |err|
              puts "#{(err.path || '').bold} #{err.description.italic}"
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
  exit
end
