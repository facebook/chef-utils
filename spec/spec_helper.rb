# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

module TasteTester
  # Null logger
  module Logging
    def logger
      Logging.logger
    end
    def self.logger
      @logger ||= Logger.new('/dev/null')
    end
  end
end

require_relative '../taste-tester/util'
require_relative '../taste-tester/config'
require_relative '../taste-tester/taste-tester'
