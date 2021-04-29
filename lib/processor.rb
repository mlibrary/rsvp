#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'json'
require 'pathname'
require 'yaml'

require 'error'
require 'shipment'
require 'string_color'

# Processor
class Processor # rubocop:disable Metrics/ClassLength
  attr_reader :dir, :options, :status, :shipment

  def initialize(dir, options = {})
    @shipment = Shipment.new(dir)
    @options = options
    @options[:config] = config
    @status = { stages: {} }
    init_status_file
    stages
  end

  def run
    # Bail out with a message if any previous stage had an error.
    discard_failure if @options[:reset]
    if @options[:restart_all] && File.directory?(@shipment.source_directory)
      puts 'Restoring from source directory...'.brown
      # FIXME: this could be an expensive operation requiring a progress bar
      @shipment.restore_from_source_directory
    end
    stages.each do |stage|
      run_stage stage
      break if @options[:one_stage] || stage_fatal_error?(stage)
    end
    query
  end

  def config
    return @config unless @config.nil?
    raise "can't locate config file #{yaml}" unless File.exist? config_file_path

    @config = symbolize YAML.load_file config_file_path
    if File.exist? local_config_file_path
      @config.merge! symbolize(YAML.load_file(local_config_file_path) || {})
    end
    @config
  end

  def config_dir
    @config_dir ||= @options[:config_dir] ||
                    File.expand_path('../config', __dir__)
  end

  def config_file_path
    @config_file_path ||= File.join(config_dir, 'config.yml')
  end

  def local_config_file_path
    @local_config_file_path ||= File.join(config_dir, 'config.local.yml')
  end

  def stages
    return @stages unless @stages.nil?

    @stages = []
    config[:stages].each do |s|
      require s[:file]
      stage_class = Object.const_get(s[:class])
      stage = stage_class.new(@shipment, @options)
      stage.name = s[:name]
      @stages << stage
    end
    @stages
  end

  def query # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    stages.each do |stage|
      print stage.name.bold + ' '
      if stage_status(stage).nil? || stage_status(stage)[:end].nil?
        puts 'not yet run'
      #FIXME: should fatal_error? be a Stage method?
      elsif stage_fatal_error? stage
        puts 'fatal error'.red
      else
        bad = stage_error_barcodes stage
        puts "#{bad.count}/#{@shipment.barcodes.count} barcodes failed," \
             " #{stage_status(stage)[:errors].count} errors," \
             " #{stage_status(stage)[:warnings].count} warnings"
      end
    end
  end

  def stage_incomplete?(stage)
    stage_status(stage).nil? || stage_status(stage)[:end].nil?
  end

  # Stage name -> Array of barcodes that have had no errors in the current run
  # Initially populated with all incomplete stages and all barcodes
  # Complete stages with errors are added with either all barcodes in the case
  # of general errors, or only the error barcodes.
  #FIXME: for stages with specific or general errors, only barcodes that
  #have files with modified timestamps should be restored from source and
  #added to the agenda
  #But what about a spurious file in Preflight?
  # if -r "retry" flag is present, run anyway
  # Otherwise, add for reprocessing only barcodes with added/deleted/changed files
  def agenda
    agenda = {}
    stages.each do |stage|
      agenda[stage.name] = []
      agenda[stage.name] = if stage_incomplete?(stage) || stage_fatal_error?(stage)
                             @shipment.barcodes.clone
                           else
                             stage_status(stage)[:errors].uniq(&:barcode).sort
                           end
    end
    agenda
  end

  def stage_status(stage)
    raise "DON'T CALL stage_status ANY MORE"
    @status[:stages][stage.name.to_sym]
  end

  # Any non-barcode-specific error halts processing.
  def stage_fatal_error?(stage)
    return false if stage_status(stage).nil?

    stage_status(stage)[:errors].any? { |e| e.barcode.nil? }
  end

  def barcode_error?(barcode)
    stages.each do |stage|
      next if stage_status(stage).nil?

      return true if stage_status(stage)[:errors].any? do |e|
        e.barcode == barcode
      end
    end
    false
  end

  def stage_error_barcodes(stage)
    return [] if stage_status(stage).nil?

    stage_status(stage)[:errors].uniq(&:barcode)
  end

  def error_query # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    eq = {}
    (@status[:metadata][:barcodes] + [nil]).each do |b|
      stages.each do |stage|
        next if stage_status(stage).nil?

        errs = stage_status(stage)[:errors].select { |e| e.barcode == b }
        next if errs.nil? || errs.none?

        (eq[b] ||= []) << { stage: stage.name, errors: errs }
      end
    end
    eq
  end

  def warning_query # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    wq = {}
    (@status[:metadata][:barcodes] + [nil]).each do |b|
      stages.each do |stage|
        next if stage_status(stage).nil?

        warns = stage_status(stage)[:warnings].select { |e| e.barcode == b }
        next if warns.nil? || warns.none?

        (wq[b] ||= []) << { stage: stage.name, warnings: warns }
      end
    end
    wq
  end

  # FIXME: the bulk of this code is shared with Postflight stage
  # See Issue #24 -- this should be moved to the Shipment class
  # or even a new metadata class.
  def metadata_query # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    unless File.directory? @shipment.source_directory
      return 'source directory not yet populated'
    end

    added = []
    removed = []
    changed = []
    @shipment.source_image_files.each do |image_file|
      if @shipment.metadata[:checksums][image_file.path].nil?
        added << image_file.path
      else
        sha256 = Digest::SHA256.file image_file.path
        if @shipment.metadata[:checksums][image_file.path] !=
           sha256.hexdigest
          changed << image_file.path
        end
      end
    end
    @shipment.metadata[:checksums].keys.map(&:to_s).each do |path|
      removed << path unless File.exist? path.to_s
    end
    "Source directory changes: #{added.count} added," \
    " #{removed.count} removed, #{changed.count} changed"
  end

  def status_file
    @status_file ||= File.join(@shipment.directory, 'status.json')
  end

  def write_status
    puts "Writing status file #{status_file}" if @options[:verbose]
    File.open(status_file, 'w') do |f|
      f.write JSON.pretty_generate({ shipment: shipment,
                                     stages: stages })
    end
  end

  private

  # Alter @status by discarding failed stage and anything after it.
  def discard_failure # rubocop:disable Metrics/AbcSize
    have_error = false
    stages.each do |stage|
      if @status[:stages][stage.name.to_sym]
        have_error ||= @status[:stages][stage.name.to_sym][:errors]&.any?
      end
      @status[:stages].delete stage.name.to_sym if have_error
    end
  end

  def run_stage(stage) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    @status[:stages][stage.name.to_sym] = { start: Time.now, errors: [] }
    stage_agenda = agenda[stage.name]
    stage.start = Time.now
    print_progress "Running stage #{stage.name} on #{stage_agenda}"
    begin
      stage.run stage_agenda
    rescue Interrupt
      puts "\nInterrupted".red
    rescue StandardError => e
      stage.add_error Error.new("#{e.inspect} #{e.backtrace}")
    ensure
      stage.cleanup
      stage.end = Time.now
    end
  end

  def init_status_file # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
    return unless File.exist? status_file

    if @options[:restart_all]
      puts "Unlinking status file #{status_file}"
      File.unlink status_file
    else
      # In order to reconstitute Error objects we need to use JSON.load
      # instead of JSON.parse. So we explicitly symbolize the output.
      # rubocop:disable Security/JSONLoad
      @status = symbolize JSON.load File.new(status_file)
      # rubocop:enable Security/JSONLoad
      raise JSON::ParserError, "unable to parse #{status_file}" if @status.nil?

      # Support legacy 'metadata' in status struct
      # This can be removed when backwards compatibility is no longer an issue.
      # The delete calls are to expose code that relies on the old data layout.
      if @status.key?(:shipment) && @status[:shipment].is_a?(Shipment)
        @shipment = @status[:shipment]
        @status.delete :shipment
      elsif @status.key? :metadata
        @shipment.metadata = @status[:metadata]
        @status.delete :metadata
      end
      @stages = @status[:stages]
    end
  end

  # Verbose printing of progress information
  def print_progress(str)
    puts str if @options[:verbose]
  end

  # Based on https://gist.github.com/Integralist/9503099
  def symbolize(obj) # rubocop:disable Metrics/MethodLength
    case obj
    when Hash
      return obj.each_with_object({}) do |(k, v), memo|
        memo.tap { |m| m[k.to_sym] = symbolize(v) }
      end
    when Array
      return obj.each_with_object([]) do |v, memo|
        memo << symbolize(v)
      end
    end
    obj
  end
end
