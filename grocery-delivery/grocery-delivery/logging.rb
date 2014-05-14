# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'syslog'

module GroceryDelivery
  # Logging wrapper
  # rubocop:disable ClassVars
  module Log
    @@init = false
    @@isdebug = false

    def self.init
      Syslog.open(File.basename($PROGRAM_NAME, '.rb'))
      @@init = true
    end

    def self.debug=(val)
      @@isdebug = val
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
      if @@isdebug
        msg.prepend('DEBUG: ')
        logit(Syslog::LOG_DEBUG, msg)
      end
    end

    def self.info(msg)
      logit(Syslog::LOG_INFO, msg)
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
