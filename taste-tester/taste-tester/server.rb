# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'fileutils'
require 'socket'
require 'timeout'

require_relative '../../between-meals/util'
require_relative 'config'

module TasteTester
  # Stateless chef-zero server management
  class Server
    include TasteTester::Config
    include TasteTester::Logging
    include ::BetweenMeals::Util

    attr_accessor :user, :host, :port

    def initialize(port = 4000)
      @ref_file = TasteTester::Config.ref_file
      ref_dir = File.dirname(File.expand_path(@ref_file))
      unless File.directory?(ref_dir)
        begin
          FileUtils.mkpath(ref_dir)
        rescue => e
          logger.info("Chef temp dir #{ref_dir} missing and can't be created")
          logger.info(e)
        end
      end
      @user = ENV['USER']
      @port = port
      @host = Socket.gethostname
    end

    def _start
      knife = BetweenMeals::Knife.new(
        :logger => logger,
        :user => @user,
        :host => @host,
        :port => @port,
        :role_dir => TasteTester::Config.roles,
        :cookbook_dirs => TasteTester::Config.cookbooks,
        :checksum_dir => TasteTester::Config.checksum_dir,
      )
      knife.write_user_config

      FileUtils.touch(@ref_file)
      Mixlib::ShellOut.new(
        "/opt/chef/embedded/bin/chef-zero --host 0.0.0.0 --port #{@port} -d"
      ).run_command.error!
    end

    def start
      return if running?
      File.delete(@ref_file) if File.exists?(@ref_file)
      logger.info('Starting taste-tester server')
      _start
    end

    def _stop
      File.delete(@ref_file) if File.exists?(@ref_file)
      s = Mixlib::ShellOut.new("pkill -9 -u #{ENV['USER']} -f bin/chef-zero")
      s.run_command
    end

    def stop
      logger.info('Stopping taste-tester server')
      _stop
    end

    def restart
      logger.info('Restarting taste-tester server')
      if running?
        _stop
        # you have to give it a moment to stop or the stat fails
        sleep(1)
      end
      _start
    end

    def self.running?(port = 4000)
      begin
        Timeout.timeout(1) do
          begin
            s = TCPSocket.new('127.0.0.1', port)
            s.close
            return true
          rescue Errno::ECONNREFUSED, Errno::EHOSTEACH
            return false
          end
        end
      rescue Timeout::Error
        return false
      end
      return false
    end

    def latest_uploaded_ref
      File.open(@ref_file, 'r').readlines.first.strip
    rescue
      false
    end

    def latest_uploaded_ref=(ref)
      File.write(@ref_file, ref)
    rescue
      logger.error('Unable to write the reffile')
    end

    def running?
      TasteTester::Server.running?
    end
  end
end
