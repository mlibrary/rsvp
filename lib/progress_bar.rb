#!/usr/bin/env ruby
# frozen_string_literal: true

# Single-line CLI ASCII art progress bar
class ProgressBar
  attr_accessor :error, :warning, :steps, :done
  attr_reader :config

  def initialize(owner = '')
    @done = 0
    @steps = 1
    @owner = owner
    @error = false
    @warning = false
    @newline = false
  end

  def step!(done, action = '')
    return if done?

    @done = done
    @done = @steps if @done > @steps
    draw action
  end

  def next!(action = '')
    step! @done + 1, action
  end

  def done?
    @done >= @steps && @newline
  end

  def done!(action = '')
    step! @steps, action
  end

  # The \033[K is to erase the entire line in case a previous action string
  # might not be completely overwritten by a subsequent shorter one.
  def draw(action = '')
    return if @newline

    progress = @steps.zero? ? 10 : 10 * @done / @steps
    bar = format '%<bar>-10s', bar: segment * progress
    bar = bar.brown if @warning
    bar = bar.red if @error
    printf("\r\033[K%-16s |%s| (#{done}/#{steps}) #{action}",
           @owner, bar)
    return unless progress >= 10

    puts "\n"
    @newline = true
  end

  private

  def segment
    @segment ||= '█'.encode('utf-8')
  end
end

# ProgressBar that doesn't draw anything
class SilentProgressBar < ProgressBar
  def draw(action = '')
    # No-op
  end
end