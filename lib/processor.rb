#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'json'
require 'pathname'
require 'yaml'

require 'error'
require 'progress_bar'
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
  end

  def run # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    # Bail out with a message if any previous stage had an error.
    discard_failure if @options[:reset]
    if had_previous_error?
      puts 'Stage failed on previous run, aborting'.red
      return
    end
    if @options[:restart_all] && File.directory?(@shipment.source_directory)
      restore_from_source_directory
    end
    stages.each do |stage|
      next unless @status[:stages][stage.name.to_sym].nil? ||
                  @status[:stages][stage.name.to_sym][:end].nil?

      run_stage stage
      break if @options[:one_stage] ||
               @status[:stages][stage.name.to_sym][:errors].any?
    end
    query
  end

  def restore_from_source_directory
    bar = ProgressBar.new('Processor')
    bar.steps = @shipment.source_barcode_directories.count
    @shipment.restore_from_source_directory do |barcode|
      bar.next! "copying from source/#{barcode}"
    end
    bar.done!
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

  def query # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    stages.each do |stage|
      stage_status = @status[:stages][stage.name.to_sym]
      print stage.name.bold + ' '
      if stage_status.nil? || stage_status[:end].nil?
        puts 'not yet run'
      elsif stage_status[:errors]&.any?
        puts "failed with #{stage_status[:errors].count} errors".red
      elsif stage_status[:warnings]&.any?
        puts "succeeded with #{stage_status[:warnings].count} warnings".brown
      else
        puts "succeeded at #{stage_status[:end]}".green
      end
    end
  end

  def error_query # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    return @error_query unless @error_query.nil?

    @error_query = {}
    (@shipment.barcodes + [nil]).each do |b|
      stages.each do |stage|
        stage_status = @status[:stages][stage.name.to_sym]
        next if stage_status.nil?

        barcode_errors = stage_status[:errors].select { |e| e.barcode == b }
        next if barcode_errors.nil? || barcode_errors.none?

        (@error_query[b] ||= []) << { stage: stage.name,
                                      errors: barcode_errors }
      end
    end
    @error_query
  end

  def warning_query # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    return @warning_query unless @warning_query.nil?

    @warning_query = {}
    (@shipment.barcodes + [nil]).each do |b|
      stages.each do |stage|
        stage_status = @status[:stages][stage.name.to_sym]
        next if stage_status.nil?

        barcode_warnings = stage_status[:warnings].select { |e| e.barcode == b }
        next if barcode_warnings.nil? || barcode_warnings.none?

        (@warning_query[b] ||= []) << { stage: stage.name,
                                        warnings: barcode_warnings }
      end
    end
    @warning_query
  end

  # FIXME: the bulk of this code is shared with Postflight stage
  # See Issue #24 -- this should be moved to the Shipment class
  # or even a new metadata class.
  def metadata_query # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    unless File.directory? @shipment.source_directory
      return 'Source directory not yet populated'
    end

    added = []
    removed = []
    changed = []
    bar = ProgressBar.new 'Metadata Check'
    bar.steps = @shipment.source_image_files.count +
                @shipment.metadata[:checksums].keys.count
    @shipment.source_image_files.each do |image_file|
      bar.next! "#{image_file.barcode_file} checksum"
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
    @shipment.metadata[:checksums].keys.sort.map(&:to_s).each do |path|
      bar.next! "#{@shipment.barcode_file_from_path(path)} existence"
      removed << path unless File.exist? path.to_s
    end
    bar.done!
    "Source directory changes: #{added.count} added," \
    " #{removed.count} removed, #{changed.count} changed"
  end

  def status_file
    @status_file ||= File.join(@shipment.directory, 'status.json')
  end

  def write_status
    puts "Writing status file #{status_file}" if @options[:verbose]
    File.open(status_file, 'w') do |f|
      f.write JSON.pretty_generate(shipment: @shipment,
                                   stages: @status[:stages])
    end
  end

  private

  def had_previous_error?
    stages.each do |stage|
      if @status[:stages][stage.name.to_sym]
        errors = @status[:stages][stage.name.to_sym][:errors]
        return true if errors&.count&.positive?
      end
    end
    false
  end

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

  # Return array of errors, possibly empty
  def run_stage(stage) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    @status[:stages][stage.name.to_sym] = { start: Time.now, errors: [] }
    errors = []
    print_progress "Running stage #{stage.name}"
    begin
      stage.run
      errors = stage.errors
    rescue StandardError => e
      errors << Error.new("#{e.inspect} #{e.backtrace}")
    ensure
      stage.cleanup
    end
    @status[:stages][stage.name.to_sym].merge!({ end: Time.now,
                                                 errors: errors,
                                                 warnings: stage.warnings,
                                                 data: stage.data || {} })
    errors
  end

  def init_status_file # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
    return unless File.exist? status_file

    if @options[:restart_all]
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
