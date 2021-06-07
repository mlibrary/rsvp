#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'
require 'readline'

require 'string_color'
require 'processor'

# Facility for running command-line processor/shipment queries and commands
class QueryTool
  attr_accessor :processor

  def initialize(processor)
    @processor = processor
  end

  def agenda_cmd(*_args) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    if processor.agenda.any?
      processor.stages.each do |stage|
        puts stage.name.bold
        barcodes_for_stage = processor.agenda.for_stage(stage)
        if (Set.new(processor.shipment.barcodes) -
            Set.new(barcodes_for_stage)).empty?
          puts '  (all barcodes)'.italic
        else
          barcodes_for_stage.each do |barcode|
            puts "  #{barcode}".italic
          end
        end
      end
    else
      puts 'NO AGENDA'.green
    end
  end

  def barcodes_cmd(*_args)
    processor.shipment.barcodes.each do |b|
      puts b.bold
    end
  end

  def errors_cmd(*args) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    errs = processor.errors_by_barcode_by_stage
    errs.each_key do |barcode|
      next if args.count.positive? && !args.include?(barcode)

      puts (barcode.nil? ? '(General)' : barcode).bold
      errs[barcode].each_key.each do |stage|
        puts stage.brown
        errs[barcode][stage].each do |err|
          puts "  #{'File'.bold}\t#{err.path}" unless err.path.nil?
          puts "  #{'Error'.bold}\t#{err.description.italic}"
        end
      end
    end
  end

  def warnings_cmd(*args) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    warnings = processor.warnings_by_barcode_by_stage
    warnings.each_key do |barcode|
      next if args.count.positive? && !args.include?(barcode)

      puts (barcode.nil? ? '(General)' : barcode).bold
      warnings[barcode].each_key.each do |stage|
        puts stage.brown
        warnings[barcode][stage].each do |err|
          puts "  #{'File'.bold}\t#{err.path}" unless err.path.nil?
          puts "  #{'Warning'.bold}\t#{err.description.italic}"
        end
      end
    end
  end

  def fixity_cmd(*_args) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    unless File.directory? processor.shipment.source_directory
      puts 'Source directory not yet populated'
    end

    bar = (processor.config[:no_progress] ? SilentProgressBar : ProgressBar)
          .new('Metadata Check')
    bar.steps = processor.shipment.source_image_files.count +
                processor.shipment.checksums.keys.count
    fixity = processor.shipment.fixity_check do |image_file|
      bar.next! image_file.barcode_file
    end
    bar.done!
    puts "Source directory changes: #{fixity[:added].count} added," \
         " #{fixity[:removed].count} removed," \
         " #{fixity[:changed].count} changed".brown
    [%i[added green], %i[removed red], %i[changed blue]].each do |params|
      next if fixity[params[0]].none?

      puts params[0].to_s.capitalize.send params[1]
      fixity[params[0]].each do |image_file|
        puts "  #{image_file.barcode_file}".italic
      end
    end
  end
end
