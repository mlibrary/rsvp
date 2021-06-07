#!/usr/bin/env ruby
# frozen_string_literal: true

# Mutable object for determining what to do with a shipment
class Agenda
  def initialize(shipment, stages)
    @shipment = shipment
    @stages = stages
    # For quick lookup of stages
    @stage_to_index = @stages.map.with_index { |s, i| [s.name.to_sym, i] }.to_h
  end

  def to_s
    "<AGENDA #{agenda}>"
  end

  # Propagate stage errors onto subsequent stages.
  def update(stage) # rubocop:disable Metrics/AbcSize
    @stages.each do |s|
      next if @stage_to_index[s.name.to_sym] <=
              @stage_to_index[stage.name.to_sym]

      if stage.fatal_error?
        agenda[s.name.to_sym] = []
      else
        agenda[s.name.to_sym].delete_if { |b| stage.error_barcodes.include? b }
      end
    end
  end

  # Stage name -> Array of barcodes that have had no errors in the current run
  def for_stage(stage)
    agenda[stage.name.to_sym] || []
  end

  def any?
    agenda.any? { |_k, v| v.count.positive? }
  end

  private

  # Called once to create to-do list of barcodes for each stage.
  # Initialized with any changes to fixity that have occurred since last run.
  def agenda
    return @agenda unless @agenda.nil?

    @agenda = {}
    todo = fixity_changes
    @stages.each do |stage|
      todo.merge @shipment.barcodes unless stage.complete?
      @agenda[stage.name.to_sym] = todo.to_a.sort
    end
    @agenda
  end

  # Array of barcodes that have had fixity {added, removed, changed} changes
  def fixity_changes
    changes = Set.new
    fixity = @shipment.fixity_check
    changes.merge fixity[:added].collect(&:barcode).compact
    changes.merge fixity[:removed].collect(&:barcode).compact
    changes.merge fixity[:changed].collect(&:barcode).compact
    changes
  end
end
