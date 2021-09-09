#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'
require 'readline'

require 'string_color'
require 'processor'

# Facility for running command-line processor/shipment queries and commands
class QueryTool # rubocop:disable Metrics/ClassLength
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

  def barcodes_cmd
    errs = processor.errors_by_barcode_by_stage
    processor.shipment.barcodes.each do |barcode|
      line = barcode.bold
      line += " #{'ERROR'.red}" if errs[barcode]
      puts line
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

  def status_cmd
    processor.stages.each do |stage|
      printf "%<name>-28s %<status>-16s %<timing>-20s %<detail>s\n",
             { name: stage.name.bold, status: status_status(stage),
               timing: status_timing(stage), detail: status_detail(stage) }
    end
  end

  def fixity_cmd # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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

  def pluralize(count, singular, plural = nil)
    if count == 1
      singular
    elsif plural
      plural
    else
      singular + 's'
    end
  end

  private

  def status_status(stage)
    if stage.end.nil?
      'not yet run'.italic
    elsif stage.fatal_error?
      'FAIL'.red
    elsif stage.errors.count.zero?
      'PASS'.green
    else
      'PARTIAL'.brown
    end
  end

  def status_detail(stage) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    statuses = []
    bad = stage.error_barcodes.count
    total = stage.barcodes.count
    errors = stage.errors.count
    if bad.positive?
      statuses << "#{bad}/#{total} #{pluralize(total, 'barcode')} failed"
      statuses << "#{errors} #{pluralize(errors, 'error').red}"
    end
    warnings = stage.warnings.count
    if warnings.positive?
      statuses << "#{warnings} #{pluralize(warnings, 'warning').brown}"
    end
    return '' unless statuses.any?

    statuses.join(', ')
  end

  def status_timing(stage)
    return '' if stage.end.nil? || stage.start.nil?

    format('%.2f sec'.italic, stage.end - stage.start)
  end
end
