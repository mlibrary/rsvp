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

# Processor
class Processor # rubocop:disable Metrics/ClassLength
  attr_reader :dir, :config, :shipment

  # Can take either a directory path or a Shipment
  def initialize(dir, options = {})
    @shipment = dir.is_a?(Shipment) ? dir : Shipment.new(dir)
    @config = Config.new(options)
    config[:stages].each do |s|
      require s[:file]
    end
    init_status_file
    stages
  end

  def run
    # open3 can be noisy if processing is interrupted with Ctrl-C.
    # This setting keeps it quiet.
    save_report_on_exception = Thread.report_on_exception
    Thread.report_on_exception = false
    if config[:restart_all] && File.directory?(@shipment.source_directory)
      restore_from_source_directory
    else
      restore_from_source_directory changed_barcodes
    end
    run_stages
    Thread.report_on_exception = save_report_on_exception
    @agenda = nil
  end

  # Remove shipment source directory and status.json if processing has finished.
  def finalize
    return unless stages.all?(&:complete?)

    bar = ProgressBar.new('(Finalize)')
    bar.steps = 1
    bar.next! 'removing source directory'
    shipment.delete_source_directory
    bar.done!
    delete_status_file
  end

  # As with Shipment#restore_from_source_directory, takes nil to replace all,
  # barcode Array otherwise.
  def restore_from_source_directory(barcodes = nil)
    return if barcodes == []

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
    config[:stages].each do |s|
      # The require step is also done when loading from JSON
      require s[:file]
      stage_class = Object.const_get(s[:class])
      stage = stage_class.new(@shipment, config: config)
      stage.name = s[:name]
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
    (@shipment.barcodes + [nil]).each do |b|
      stages.each do |stage|
        stage_errs = stage.errors.select { |e| e.barcode == b }
        next if stage_errs.none?

        (errs[b] ||= {})[stage.name] = stage_errs
      end
    end
    errs
  end

  # Map of barcode + nil -> stage name -> [Errors]
  # Does not include barcodes with no warnings
  def warnings_by_barcode_by_stage
    warnings = {}
    (@shipment.barcodes + [nil]).each do |b|
      stages.each do |stage|
        stage_warnings = stage.warnings.select { |e| e.barcode == b }
        next if stage_warnings.none?

        (warnings[b] ||= {})[stage.name] = stage_warnings
      end
    end
    warnings
  end

  def status_file
    @status_file ||= File.join(@shipment.directory, 'status.json')
  end

  def status_file_deleted?
    @status_file_deleted
  end

  def write_status_file
    return if @status_file_deleted

    puts "Writing status file #{status_file}" if config[:verbose]
    File.open(status_file, 'w') do |f|
      f.write JSON.pretty_generate({ shipment: shipment,
                                     stages: stages })
    end
  end

  private

  def delete_status_file
    return unless File.exist? status_file

    FileUtils.rm status_file
    @status_file_deleted = true
  end

  def run_stages
    stages.each do |stage|
      run_stage stage
      break if stage.fatal_error?
    end
  end

  def run_stage(stage) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    stage_agenda = agenda.for_stage stage
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
    return unless File.exist? status_file

    if config[:restart_all]
      File.unlink status_file
    else
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
             status[:stages].all? { |s| s.is_a? Stage }
        raise StandardError, 'status.json has no Stage array'
      end

      @shipment = status[:shipment]
      @stages = status[:stages]
      @stages.each do |s|
        s.shipment = @shipment
        s.config = @config
      end
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
