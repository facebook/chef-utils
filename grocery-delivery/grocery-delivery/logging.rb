# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'syslog'
require 'logger'

module GroceryDelivery
  # Logging wrapper
  # rubocop:disable ClassVars
  module Log
    @@init = false
    @@level = Logger::WARN

    def self.init
      Syslog.open(File.basename($PROGRAM_NAME, '.rb'))
      @@init = true
    end

    def self.verbosity=(val)
      @@level = val
    end

    def self.logit(level, msg)
      init unless @@init
      # You can't do `Syslog.log(level, msg)` because if there is a
      # `%` in `msg` then ruby will interpret it as a printf string and
      # expect more arguments to log().
      Syslog.log(level, '%s', msg)
      puts msg if $stdout.tty?
    end

    def self.debug(msg)
      if @@level == Logger::DEBUG
        msg.prepend('DEBUG: ')
        logit(Syslog::LOG_DEBUG, msg)
      end
    end

    def self.info(msg)
      if @@level == Logger::INFO
        msg.prepend('INFO: ')
        logit(Syslog::LOG_INFO, msg)
      end
    end

    def self.warn(msg)
      msg.prepend('WARN: ')
      logit(Syslog::LOG_WARNING, msg)
    end

    def self.error(msg)
      msg.prepend('ERROR: ')
      logit(Syslog::LOG_ERR, msg)
    end
  end
  # rubocop:enable ClassVars
end
