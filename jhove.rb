#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'
require 'optparse'

APP_ROOT = File.expand_path(__dir__)
$LOAD_PATH << File.join(APP_ROOT, 'lib')
$LOAD_PATH << File.join(APP_ROOT, 'lib/stage')
require 'config'
require 'jhove'
require 'string_color'

options_data = [['-c', '--config-profile PROFILE', :config_profile,
                 'Configuration PROFILE (e.g., "dlxs")'],
                ['-d', '--config-dir DIRECTORY', :config_dir,
                 'Configuration directory DIRECTORY'],
                ['-h', '--help', :help,
                 'Display this message and exit'],
                ['-v', '--verbose', :verbose,
                 'Write raw validate_images.pl/JHOVE output']].freeze
options = {}
opts = OptionParser.new
opts.banner = "Usage: #{$PROGRAM_NAME} [options]" \
              'SHIPMENT_DIRECTORY [SHIPMENT_DIRECTORY...]'
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

args = $stdin.tty? ? ARGV : $stdin.read.split("\n")
if args.count.zero?
  puts 'Missing required parameter SHIPMENT_DIRECTORY'.red
  puts opts.help
  exit 1
end

# Map of path to string
statuses = {}

err_file = ['jhove', Time.now.strftime('%Y%m%d_%H%M%S'), 'errors.txt'].join '_'
outfile = File.open err_file, 'w'

args.each do |arg| # rubocop:disable Metrics/BlockLength
  dir = Pathname.new(arg).cleanpath.to_s
  unless File.exist? dir
    statuses[arg] = 'No such directory'.red
    next
  end
  unless File.directory? dir
    statuses[arg] = 'Not a directory'.red
    next
  end
  outfile.puts "========== #{arg} =========="
  config = Config.new(options)
  jhove = JHOVE.new(dir, config)
  jhove.run
  statuses[arg] = jhove.errors.none? ? 'OK'.green : 'ERRORS'.red
  if options[:verbose]
    outfile.write jhove.raw_output
    next
  end
  jhove.error_fields.each do |field|
    outfile.puts field.to_s.capitalize
    jhove.errors_for_field(field).each do |err|
      expected = ''
      unless err[:expected].nil? || err[:actual].nil?
        expected = " (expected: #{err[:expected]}, actual: #{err[:actual]})"
      end
      outfile.puts "  #{err[:file]}#{expected}"
    end
  end
end

outfile.close
statuses.each do |path, status|
  puts "#{status.bold} #{path}"
end
puts "Output written to #{err_file}"
