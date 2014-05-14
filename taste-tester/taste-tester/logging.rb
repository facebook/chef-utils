# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
# rubocop:disable ClassVars, UnusedMethodArgument, UnusedBlockArgument
require 'logger'

module TasteTester
  # Logging wrapper
  module Logging
    @@use_log_formatter = false
    @@level = Logger::INFO
    @@formatter_proc = nil

    def logger
      logger = Logging.logger
      logger.formatter = formatter
      logger.level = @@level
      logger
    end

    def self.logger
      @logger ||= Logger.new(STDOUT)
    end

    def self.formatterproc=(p)
      @@formatter_proc = p
    end

    def self.use_log_formatter=(use_log_formatter)
      @@use_log_formatter = use_log_formatter
    end

    def self.debug=(debug)
      if debug
        @@level = Logger::DEBUG
      else
        @@level = Logger::INFO
      end
    end

    def formatter(x = 1)
      return @@formatter_proc if @@formatter_proc
      if @@use_log_formatter
        proc do |severity, datetime, progname, msg|
          if severity == 'ERROR'
            msg = msg.red
          end
          "[#{datetime.strftime('%Y-%m-%dT%H:%M:%S%:z')}] #{severity}: #{msg}\n"
        end
      else
        proc do |severity, datetime, progname, msg|
          msg.prepend("#{severity}: ") unless severity == 'INFO'
          if severity == 'ERROR'
            msg = msg.red
          end
          "#{msg}\n"
        end
      end
    end
  end
end
