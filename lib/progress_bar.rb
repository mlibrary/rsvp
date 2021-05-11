#!/usr/bin/env ruby
# frozen_string_literal: true

# Single-line CLI ASCII art progress bar
class ProgressBar
  attr_accessor :error, :steps
  attr_reader :done

  def initialize(owner = '', options = {})
    @done = 0
    @steps = 1
    @owner = owner
    @options = options
    @error = false
    @newline = false
  end

  def step!(obj, action = '')
    return if done?

    @done = obj
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
    return if @options[:no_progress] || @newline

    progress = @steps.zero? ? 0 : 10 * @done / @steps
    bar = format '%<bar>-10s', bar: block * progress
    bar = bar.red if @error
    printf("\r\033[K%-16s |%s| (#{done}/#{steps}) #{action}",
           @owner, bar)
    return unless progress >= 10

    puts "\n"
    @newline = true
  end

  private

  def block
    @block ||= '█'.encode('utf-8')
  end
end
