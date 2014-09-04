# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'fileutils'
require 'socket'
require 'timeout'

require_relative '../../between-meals/util'
require_relative 'config'
require_relative 'state'

module TasteTester
  # Stateless chef-zero server management
  class Server
    include TasteTester::Config
    include TasteTester::Logging
    extend ::BetweenMeals::Util

    attr_accessor :user, :host

    def initialize
      @state = TasteTester::State.new
      @ref_file = TasteTester::Config.ref_file
      ref_dir = File.dirname(File.expand_path(@ref_file))
      @zero_path = TasteTester::Config.chef_zero_path
      unless File.directory?(ref_dir)
        begin
          FileUtils.mkpath(ref_dir)
        rescue => e
          logger.warn("Chef temp dir #{ref_dir} missing and can't be created")
          logger.warn(e)
        end
      end

      @user = ENV['USER']

      # If we are using SSH tunneling listen on localhost, otherwise listen
      # on all addresses - both v4 and v6. Note that on localhost, ::1 is
      # v6-only, so we default to 127.0.0.1 instead.
      @addr = TasteTester::Config.use_ssh_tunnels ? '127.0.0.1' : '::'
      @host = 'localhost'
    end

    def start
      return if TasteTester::Server.running?
      @state.wipe
      logger.warn('Starting taste-tester server')
      write_config
      start_chef_zero
    end

    def stop
      logger.warn('Stopping taste-tester server')
      stop_chef_zero
    end

    def restart
      logger.warn('Restarting taste-tester server')
      if TasteTester::Server.running?
        stop_chef_zero
      end
      write_config
      start_chef_zero
    end

    def port
      @state.port
    end

    def port=(port)
      @state.port = port
    end

    def latest_uploaded_ref
      @state.ref
    end

    def latest_uploaded_ref=(ref)
      @state.ref = ref
    end

    def self.running?
      if TasteTester::State.port
        return port_open?(TasteTester::State.port)
      end
      false
    end

    private

    def write_config
      knife = BetweenMeals::Knife.new(
        :logger => logger,
        :user => @user,
        :host => @host,
        :port => port,
        :role_dir => TasteTester::Config.roles,
        :cookbook_dirs => TasteTester::Config.cookbooks,
        :checksum_dir => TasteTester::Config.checksum_dir,
      )
      knife.write_user_config
    end

    def start_chef_zero
      @state.wipe
      @state.port = TasteTester::Config.chef_port
      logger.info("Starting chef-zero of port #{@state.port}")
      Mixlib::ShellOut.new(
        "/opt/chef/embedded/bin/chef-zero --host #{@addr}" +
        " --port #{@state.port} -d"
      ).run_command.error!
    end

    def stop_chef_zero
      @state.wipe
      logger.info('Killing your chef-zero instances')
      s = Mixlib::ShellOut.new("pkill -9 -u #{ENV['USER']} -f bin/chef-zero")
      s.run_command
      # You have to give it a moment to stop or the stat fails
      sleep(1)
    end
  end
end
