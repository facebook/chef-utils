# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'fileutils'
require 'base64'
require 'open3'
require 'colorize'

require_relative 'ssh'
require_relative 'tunnel'

module TasteTester
  # Manage state of the remote node
  class Host
    include TasteTester::Logging

    attr_reader :name

    def initialize(name, server)
      @name = name
      @user = ENV['USER']
      @server = server
      @tunnel = TasteTester::Tunnel.new(@name, @server)
    end

    def runchef
      logger.warn("Running '#{TasteTester::Config.command}' on #{@name}")
      cmd = "ssh #{TasteTester::Config.user}@#{@name} "
      if TasteTester::Config.user != 'root'
        cc = Base64.encode64(cmds).gsub(/\n/, '')
        cmd += "\"echo '#{cc}' | base64 --decode | sudo bash -x\""
      else
        cmd += "\"#{cmds}\""
      end
      status = IO.popen(
        cmd
      ) do |io|
        # rubocop:disable AssignmentInCondition
        while line = io.gets
          puts line.chomp!
        end
        # rubocop:enable AssignmentInCondition
        io.close
        $CHILD_STATUS.to_i
      end
      logger.warn("Finished #{TasteTester::Config.command}" +
                  " on #{@name} with status #{status}")
      if status == 0
        msg = "#{TasteTester::Config.command} was successful" +
          ' - please log to the host and confirm all the intended' +
          ' changes were made'
        logger.error msg.upcase
      end
    end

    def test
      logger.warn("Taste-testing on #{@name}")

      # Nuke any existing tunnels that may be there
      TasteTester::Tunnel.kill(@name)

      # Then setup the tunnel
      @tunnel.run
      @serialized_config = Base64.encode64(config).gsub(/\n/, '')

      # Then setup the testing
      ssh = TasteTester::SSH.new(@name)
      ssh << 'logger -t taste-tester Moving server into taste-tester' +
        " for #{@user}"
      ssh << "touch -t #{TasteTester::Config.testing_end_time}" +
        " #{TasteTester::Config.timestamp_file}"
      ssh << "echo -n '#{@serialized_config}' | base64 --decode" +
        ' > /etc/chef/client-taste-tester.rb'
      ssh << 'rm -vf /etc/chef/client.rb'
      ssh << '( ln -vs /etc/chef/client-taste-tester.rb' +
        ' /etc/chef/client.rb; true )'
      ssh.run!

      # Then run any other stuff they wanted
      cmds = TasteTester::Hooks.test_remote_cmds(
        TasteTester::Config.dryrun,
        @name
      )

      if cmds && cmds.any?
        ssh = TasteTester::SSH.new(@name)
        cmds.each { |c| ssh << c }
        ssh.run!
      end
    end

    def untest
      logger.warn("Removing #{@name} from taste-tester")
      ssh = TasteTester::SSH.new(@name)
      TasteTester::Tunnel.kill(@name)
      ssh << 'rm -vf /etc/chef/client.rb'
      ssh << 'rm -vf /etc/chef/client-taste-tester.rb'
      ssh << 'ln -vs /etc/chef/client-prod.rb /etc/chef/client.rb'
      ssh << 'rm -vf /etc/chef/client.pem'
      ssh << 'ln -vs /etc/chef/client-prod.pem /etc/chef/client.pem'
      ssh << "rm -vf #{TasteTester::Config.timestamp_file}"
      ssh << 'logger -t taste-tester Returning server to production'
      ssh.run!
    end

    def who_is_testing
      ssh = TasteTester::SSH.new(@name)
      ssh << 'grep "^# TasteTester by" /etc/chef/client.rb'
      output = ssh.run
      if output.first == 0
        user = output.last.match(/# TasteTester by (.*)$/)
        if user
          return user[1]
        end
      end

      # Legacy FB stuff, remove after migration. Safe for everyone else.
      ssh = TasteTester::SSH.new(@name)
      ssh << 'file /etc/chef/client.rb'
      output = ssh.run
      if output.first == 0
        user = output.last.match(/client-(.*)-(taste-tester|test).rb/)
        if user
          return user[1]
        end
      end

      return nil
    end

    def in_test?
      ssh = TasteTester::SSH.new(@name)
      ssh << "test -f #{TasteTester::Config.timestamp_file}"
      if ssh.run.first == 0 && who_is_testing && who_is_testing != ENV['USER']
        true
      else
        false
      end
    end

    def keeptesting
      logger.warn("Renewing taste-tester on #{@name} until" +
        " #{TasteTester::Config.testing_end_time}")
      TasteTester::Tunnel.kill(@name)
      @tunnel = TasteTester::Tunnel.new(@name, @server)
      @tunnel.run
    end

    private

    def config
      if TasteTester::Config.use_ssh_tunnels
        url = "http://localhost:#{@tunnel.port}"
      else
        url = "http://#{@server.host}:#{TasteTester::State.port}"
      end
      ttconfig = <<-eos
# TasteTester by #{@user}
# Prevent people from screwing up their permissions
if Process.euid != 0
  puts 'Please run chef as root!'
  Process.exit!
end

log_level                :info
log_location             STDOUT
chef_server_url          '#{url}'
Ohai::Config[:plugin_path] << '/etc/chef/ohai_plugins'

      eos

      extra = TasteTester::Hooks.test_remote_client_rb_extra_code(@name)
      if extra
        ttconfig += <<-eos
# Begin user-hook specified code
        #{extra}
# End user-hook secified code

        eos
      end

      ttconfig += <<-eos
puts 'INFO: Running on #{@name} in taste-tester by #{@user}'
      eos
      return ttconfig
    end
  end
end
