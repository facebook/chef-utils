# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'colorize'

module BetweenMeals
  # A set of simple utility functions used throughout BetweenMeals
  #
  # Feel freeo to use... note that if you pass in a logger once
  # you don't need to again, but be safe and always pass one in. :)

  # Util classes need class vars :)
  # rubocop:disable ClassVars
  module Util
    @@logger = nil

    def time(logger = nil)
      @@logger = logger if logger
      t0 = Time.now
      yield
      debug("Executed in #{format('%.2f', Time.now - t0)}s")
    end

    def exec!(command, logger = nil)
      @@logger = logger if logger
      c = execute(command)
      c.error!
      return c.status.exitstatus, c.stdout
    end

    def exec(command, logger = nil)
      @@logger = logger if logger
      c = execute(command)
      return c.status.exitstatus, c.stdout
    end

    private

    def debug(msg)
      @@logger.debug(msg) if @@logger
    end

    def execute(command)
      debug("Running: #{command}")
      c = Mixlib::ShellOut.new(command)
      c.run_command
      c.stdout.lines.each do |line|
        debug("STDOUT: #{line.strip}")
      end
      c.stderr.lines.each do |line|
        debug("STDERR: #{line.strip.red}")
      end
      return c
    end
  end
end
