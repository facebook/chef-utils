# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'colorize'
require 'socket'
require 'timeout'

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
      info("Executed in #{format('%.2f', Time.now - t0)}s")
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

    def info(msg)
      @@logger.info(msg) if @@logger
    end

    def execute(command)
      info("Running: #{command}")
      c = Mixlib::ShellOut.new(command)
      c.run_command
      c.stdout.lines.each do |line|
        info("STDOUT: #{line.strip}")
      end
      c.stderr.lines.each do |line|
        info("STDERR: #{line.strip.red}")
      end
      return c
    end

    def port_open?(port)
      begin
        Timeout.timeout(1) do
          begin
            s = TCPSocket.new('localhost', port)
            s.close
            return true
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            return false
          end
        end
      rescue Timeout::Error
        return false
      end
      return false
    end
  end
end
