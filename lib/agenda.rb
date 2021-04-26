#!/usr/bin/env ruby
# frozen_string_literal: true

# Mutable object for determining what to do with a shipment
class Agenda
  def initialize(shipment, stages)
    @shipment = shipment
    @stages = stages
  end

  def contains?(barcode)
    true
  end
end

class DefaultAgenda < Agenda

  def contains?(barcode)
    true
  end
end
