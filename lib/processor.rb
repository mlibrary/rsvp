#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'pathname'
require 'yaml'
require 'string_color'

# Processor
class Processor # rubocop:disable Metrics/ClassLength
  attr_reader :dir, :options, :status

  def initialize(dir, options = {})
    @dir = dir
    @options = options
    @options[:config] = config
    @status = { stages: {}, metadata: {} }
    init_status_file
  end

  def run # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    # Bail out with a message if any previous stage had an error.
    discard_failure if @options[:reset]
    if had_previous_error?
      puts 'Stage failed on previous run, aborting'.red
      return
    end
    stages.each do |stage|
      next unless @status[:stages][stage.name.to_sym].nil? ||
                  @status[:stages][stage.name.to_sym][:end].nil?

      run_stage stage
      report_stage_errors(stage)
      report_stage_warnings(stage)
      break if @options[:one_stage] ||
               @status[:stages][stage.name.to_sym][:errors].any?
    end
  end

  def config
    return @config unless @config.nil?

    config_dir = File.expand_path('../config', __dir__)
    config_dir = @options[:config_dir] if @options.key?(:config_dir)
    yaml = File.join(config_dir, 'config.yml')
    raise "can't locate config file #{yaml}" unless File.exist? yaml

    @config = symbolize YAML.load_file yaml
    local_yaml = File.join(config_dir, 'config.local.yml')
    @config.merge! symbolize YAML.load_file local_yaml if File.exist? local_yaml
    @config
  end

  def stages
    return @stages unless @stages.nil?

    @stages = []
    config[:stages].each do |s|
      require s[:file]
      stage_class = Object.const_get(s[:class])
      stage = stage_class.new(@dir, @status[:metadata], @options)
      stage.name = s[:name]
      @stages << stage
    end
    @stages
  end

  def query # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    puts "===== SHIPMENT #{@dir} STATUS =====".blue
    stages.each do |stage|
      stage_status = @status[:stages][stage.name.to_sym]
      if stage_status.nil? || stage_status[:end].nil?
        puts stage.name.bold + ' not yet run'
      elsif stage_status[:errors]&.any?
        report_stage_errors(stage, false)
      else
        puts stage.name.bold + " succeeded at #{stage_status[:end]}".green
      end
      report_stage_warnings(stage)
    end
  end

  def status_file
    @status_file ||= File.join(@dir, 'status.json')
  end

  def write_status
    puts "Writing status file #{status_file}" if @options[:verbose]
    File.open(status_file, 'w') do |f|
      f.write JSON.pretty_generate(@status)
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

  def report_stage_errors(stage, truncate = true) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return unless @status[:stages][stage.name.to_sym] &&
                  @status[:stages][stage.name.to_sym][:errors]&.any?

    puts stage.name.bold + ' failed with errors:'.red
    @status[:stages][stage.name.to_sym][:errors].each_with_index do |e, i|
      if i >= 10 && truncate
        more = @status[:stages][stage.name.to_sym][:errors].count - 10
        puts "  (... and #{more} more. Run ./query for the full list)".red
        break
      else
        puts "  #{e}".red
      end
    end
  end

  def report_stage_warnings(stage) # rubocop:disable Metrics/AbcSize
    return unless @status[:stages][stage.name.to_sym] &&
                  @status[:stages][stage.name.to_sym][:warnings]&.any?

    puts stage.name.bold + ' warnings:'.brown
    @status[:stages][stage.name.to_sym][:warnings].each do |e|
      puts "  #{e}".brown
    end
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
      errors << "#{e.inspect} #{e.backtrace}"
    ensure
      stage.cleanup
    end
    @status[:stages][stage.name.to_sym].merge!({ end: Time.now,
                                                 errors: errors,
                                                 warnings: stage.warnings,
                                                 data: stage.data || {} })
    errors
  end

  def init_status_file
    return unless File.exist? status_file

    if @options[:restart_all]
      File.unlink status_file
    else
      @status = JSON.parse(File.read(status_file), symbolize_names: true)
      # Fix up old status.json files during testing
      @status[:metadata] = {} unless @status.key? :metadata
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
