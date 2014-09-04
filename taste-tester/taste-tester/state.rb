# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'fileutils'
require 'socket'
require 'timeout'

require_relative '../../between-meals/util'
require_relative 'config'

module TasteTester
  # State of taste-tester processes
  class State
    include TasteTester::Config
    include TasteTester::Logging
    include ::BetweenMeals::Util

    def initialize
      ref_dir = File.dirname(File.expand_path(
        TasteTester::Config.ref_file
      ))
      unless File.directory?(ref_dir)
        begin
          FileUtils.mkpath(ref_dir)
        rescue => e
          logger.error("Chef temp dir #{ref_dir} missing and can't be created")
          logger.error(e)
          exit(1)
        end
      end
    end

    def port
      TasteTester::State.read(:port)
    end

    def port=(port)
      write(:port, port)
    end

    def ref
      TasteTester::State.read(:ref)
    end

    def ref=(ref)
      write(:ref, ref)
    end

    def self.port
      TasteTester::State.read(:port)
    end

    def wipe
      if TasteTester::Config.ref_file &&
          File.exists?(TasteTester::Config.ref_file)
        File.delete(TasteTester::Config.ref_file)
      end
    end

    private

    def write(key, value)
      begin
        state = JSON.parse(File.read(TasteTester::Config.ref_file))
      rescue
        state = {}
      end
      state[key.to_s] = value
      ff = File.open(
        TasteTester::Config.ref_file,
        'w'
      )
      ff.write(state.to_json)
      ff.close
    rescue => e
      logger.error('Unable to write the reffile')
      logger.debug(e)
      exit 0
    end

    def self.read(key)
      JSON.parse(File.read(TasteTester::Config.ref_file))[key.to_s]
    rescue => e
      logger.debug(e)
      nil
    end
  end
end
