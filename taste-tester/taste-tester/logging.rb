# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
# rubocop:disable ClassVars, UnusedMethodArgument, UnusedBlockArgument
require 'logger'

module TasteTester
  # Logging wrapper
  module Logging
    @@use_log_formatter = false
    @@level = Logger::WARN
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

    def self.verbosity=(level)
      @@level = level
    end

    def formatter
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
          msg.to_s.prepend("#{severity}: ") unless severity == 'WARN'
          if severity == 'ERROR'
            msg = msg.to_s.red
          end
          "#{msg}\n"
        end
      end
    end
  end
end
