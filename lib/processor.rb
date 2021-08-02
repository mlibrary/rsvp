#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'pathname'
require 'yaml'

require 'agenda'
require 'config'
require 'error'
require 'progress_bar'
require 'shipment'
require 'stage'
require 'string_color'
require 'symbolize'

Dir[File.join(__dir__, 'stage', '*.rb')].sort.each { |file| require file }

# Processor
class Processor # rubocop:disable Metrics/ClassLength
  attr_reader :dir, :config, :shipment

  # Can take a Shipment instead of a directory.
  # This is mainly as a shortcut for testing and is not otherwise recommended.
  def initialize(dir, options = {})
    @dir = dir.is_a?(Shipment) ? dir.directory : dir
    @config = Config.new(options)
    unless init_status_file
      @shipment = dir.is_a?(Shipment) ? dir : shipment_class.new(dir)
    end
    stages
  end

  def shipment_class
    Object.const_get(@config[:shipment_class] || 'Shipment')
  end

  def run # rubocop:disable Metrics/MethodLength
    raise FinalizedShipmentError if shipment.finalized?

    if config[:restart_all]
      restore_from_source_directory
    else
      restore_from_source_directory changed_barcodes
    end
    # Keep open3 quiet when processing is interrupted with Ctrl-C.
    save_report_on_exception = Thread.report_on_exception
    Thread.report_on_exception = false
    run_stages
    Thread.report_on_exception = save_report_on_exception
    @agenda = nil
  end

  # Remove shipment source directory if processing has finished.
  def finalize
    return unless stages.all?(&:complete?)

    bar = ProgressBar.new('(Finalize)')
    bar.steps = 1
    bar.next! 'finalizing shipment'
    shipment.finalize
    bar.done!
  end

  # As with Shipment#restore_from_source_directory, takes nil to replace all,
  # barcode Array otherwise.
  def restore_from_source_directory(barcodes = nil)
    return if barcodes == []
    return unless File.directory? shipment.source_directory

    bar = ProgressBar.new('(Restore)')
    bar.steps = @shipment.source_barcode_directories.count
    @shipment.restore_from_source_directory(barcodes) do |barcode|
      bar.next! "copying from source/#{barcode}"
    end
    bar.done!
  end

  def stages
    return @stages unless @stages.nil?

    @stages = []
    config[:stages].each do |stage_info|
      stage_class = Object.const_get(stage_info[:class])
      stage = stage_class.new(@shipment, config: config)
      stage.name = stage_info[:name]
      @stages << stage
    end
    @stages
  end

  def agenda
    @agenda ||= Agenda.new(@shipment, @stages)
  end

  # Map of stage name -> barcode + nil -> [Errors]
  # Does not include stages with no errors
  def errors
    errs = {}
    stages.each do |stage|
      stage_errs = stage.errors_by_barcode
      errs[stage.name] = stage_errs unless stage_errs.empty?
    end
    errs
  end

  # Map of stage name -> barcode + nil -> [Errors]
  # Does not include stages with no errors
  def warnings
    warnings = {}
    stages.each do |stage|
      stage_warnings = stage.warnings_by_barcode
      warnings[stage.name] = stage_warnings unless stage_warnings.empty?
    end
    warnings
  end

  # Map of barcode + nil -> stage name -> [Errors]
  # Does not include barcodes with no errors
  def errors_by_barcode_by_stage
    errs = {}
    (@shipment.barcodes + [nil]).each do |barcode|
      stages.each do |stage|
        stage_errs = stage.errors.select { |err| err.barcode == barcode }
        next if stage_errs.none?

        (errs[barcode] ||= {})[stage.name] = stage_errs
      end
    end
    errs
  end

  # Map of barcode + nil -> stage name -> [Errors]
  # Does not include barcodes with no warnings
  def warnings_by_barcode_by_stage
    warnings = {}
    (@shipment.barcodes + [nil]).each do |barcode|
      stages.each do |stage|
        stage_warnings = stage.warnings.select { |err| err.barcode == barcode }
        next if stage_warnings.none?

        (warnings[barcode] ||= {})[stage.name] = stage_warnings
      end
    end
    warnings
  end

  def status_file
    @status_file ||= File.join(@dir, 'status.json')
  end

  def status_file?
    File.exist? status_file
  end

  def write_status_file
    puts "Writing status file #{status_file}" if config[:verbose]
    File.open(status_file, 'w') do |file|
      config_copy = @config.dup
      config_copy.delete :restart_all
      file.write JSON.pretty_generate({ config: config_copy,
                                        shipment: shipment,
                                        stages: stages })
    end
  end

  private

  def run_stages
    stages.each do |stage|
      run_stage stage
      break if stage.fatal_error?
    end
  end

  def run_stage(stage) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    stage_agenda = agenda.for_stage stage
    return if stage_agenda.none?

    stage.reinitialize!
    print_progress "Running stage #{stage.name} with #{agenda}"
    interrupt = false
    begin
      stage.run! stage_agenda
    rescue Interrupt
      puts "\nInterrupted".red
      stage.add_error Error.new('Interruped')
      interrupt = true
    rescue StandardError => e
      stage.add_error Error.new("#{e.inspect} #{e.backtrace}")
      puts "#{e.inspect} #{e.backtrace}"
    ensure
      stage.cleanup interrupt
      agenda.update stage
    end
  end

  def init_status_file # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    return false unless File.exist? status_file

    # In order to reconstitute Error objects we need to use JSON.load
    # instead of JSON.parse. So we explicitly symbolize the output.
    # rubocop:disable Security/JSONLoad
    status = Symbolize.symbolize JSON.load File.new(status_file)
    # rubocop:enable Security/JSONLoad
    raise JSON::ParserError, "unable to parse #{status_file}" if status.nil?

    unless status.key?(:shipment) && status[:shipment].is_a?(Shipment)
      raise StandardError, 'status.json has no Shipment object'
    end

    unless status.key?(:stages) && status[:stages].is_a?(Array) &&
           status[:stages].all? { |stage| stage.is_a? Stage }
      raise StandardError, 'status.json has no Stage array'
    end

    if config[:restart_all]
      raise FinalizedShipmentError if status[:shipment].finalized?

      false
    else
      unless status[:config].nil?
        save_config = @config
        @config = status[:config]
        @config.merge! save_config
      end
      @shipment = status[:shipment]
      @shipment.directory = @dir
      @stages = status[:stages]
      @stages.each do |stage|
        stage.shipment = @shipment
        stage.config = @config
      end
      true
    end
  end

  def changed_barcodes
    fixity = shipment.fixity_check
    [fixity[:added].collect(&:barcode),
     fixity[:removed].collect(&:barcode),
     fixity[:changed].collect(&:barcode)].flatten.uniq
  end

  # Verbose printing of progress information
  def print_progress(str)
    puts str if config[:verbose]
  end
end
