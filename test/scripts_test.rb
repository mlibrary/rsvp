#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'

class ScriptsTest < Minitest::Test
  SCRIPTS = %w[jhove process query shipments].freeze

  def test_sh_scripts
    ScriptsTest::SCRIPTS.each do |script|
      cmd = "#{File.join(APP_ROOT, script + '.sh')} -h"
      _stdout_str, _stderr_str, code = Open3.capture3(cmd)
      assert code.success?, "#{cmd} runs without error"
    end
  end

  def test_rb_scripts
    ScriptsTest::SCRIPTS.each do |script|
      cmd = "bundle exec #{File.join(APP_ROOT, script + '.rb')} -h"
      _stdout_str, _stderr_str, code = Open3.capture3(cmd)
      assert code.success?, "#{cmd} runs without error"
    end
  end
end
