# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'fileutils'
require 'base64'
require 'open3'
require 'colorize'

require_relative 'ssh'

module TasteTester
  # Manage remote cehftest node
  class Host
    include TasteTester::Logging

    attr_reader :name

    def initialize(name, server)
      @name = name
      @user = ENV['USER']
      @chef_server = server.host
      @serialized_config = Base64.encode64(config).gsub(/\n/, '')
      if TasteTester::Config.testing_until
        @timestamp = TasteTester::Config.testing_until.
          strftime('%y%m%d%H%M.%S')
        @delta_secs = TasteTester::Config.testing_until.strftime('%s').to_i -
                      Time.now.strftime('%s').to_i
      else
        @timestamp = (Time.now + TasteTester::Config.testing_time).
          strftime('%y%m%d%H%M.%S')
        @delta_secs = TasteTester::Config.testing_time
      end
      @tsfile = '/etc/chef/test_timestamp'
    end

    def runchef
      logger.warn("Running '#{TasteTester::Config.command}' on #{@name}")
      status = IO.popen(
        "ssh root@#{@name} #{TasteTester::Config.command}"
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

    def nuke_old_tunnel
      ssh = TasteTester::SSH.new(@name)
      # Since commands are &&'d together, and we're using &&, we need to
      # surround this in paryns, and make sure as a whole it evaluates
      # to true so it doesn't mess up other things... even though this is
      # the only thing we're currently executing in this SSH.
      ssh << "( [ -s #{@tsfile} ] && kill -- -\$(cat #{@tsfile}); true )"
      ssh.run!
    end

    def setup_tunnel
      ssh = TasteTester::SSH.new(@name, 5, true)
      ssh << "echo \\\$\\\$ > #{@tsfile}"
      ssh << "touch -t #{@timestamp} #{@tsfile}"
      ssh << "sleep #{@delta_secs}"
      ssh.run!
    end

    def test
      logger.warn("Taste-testing on #{@name}")

      # Nuke any existing tunnels that may be there
      nuke_old_tunnel

      # Then setup the testing
      ssh = TasteTester::SSH.new(@name)
      ssh << 'logger -t taste-tester Moving server into taste-tester' +
        " for #{@user}"
      ssh << "touch -t #{@timestamp} #{@tsfile}"
      ssh << "echo -n '#{@serialized_config}' | base64 --decode" +
        ' > /etc/chef/client-taste-tester.rb'
      ssh << 'rm -vf /etc/chef/client.rb'
      ssh << '( ln -vs /etc/chef/client-taste-tester.rb' +
        ' /etc/chef/client.rb; true )'
      ssh.run!

      # Then setup the tunnel
      setup_tunnel

      # Then run any other stuff they wanted
      cmds = TasteTester::Hooks.test_remote_cmds(TasteTester::Config.dryrun,
                                                 @name)
      if cmds && cmds.any?
        ssh = TasteTester::SSH.new(@name)
        cmds.each { |c| ssh << c }
        ssh.run!
      end
    end

    def untest
      logger.warn("Removing #{@name} from taste-tester")
      ssh = TasteTester::SSH.new(@name)
      # see above for why this command is funky
      # We do this even if use_ssh_tunnels is false because we may be switching
      # from one to the other
      ssh << "( [ -s #{@tsfile} ] && kill -- -\$(cat #{@tsfile}); true )"
      ssh << 'rm -vf /etc/chef/client.rb'
      ssh << 'rm -vf /etc/chef/client-taste-tester.rb'
      ssh << 'ln -vs /etc/chef/client-prod.rb /etc/chef/client.rb'
      ssh << 'rm -vf /etc/chef/client.pem'
      ssh << 'ln -vs /etc/chef/client-prod.pem /etc/chef/client.pem'
      ssh << 'rm -vf /etc/chef/test_timestamp'
      ssh << 'logger -t taste-tester Returning server to production'
      ssh.run!
    end

    def who_is_testing
      ssh = TasteTester::SSH.new(@name)
      ssh << 'grep \'^# TasteTester by\' /etc/chef/client.rb'
      user = ssh.run.last.match(/# TasteTester by (.*)$/)
      if user
        user[1]
      else
        # Legacy FB stuff, remove after migration. Safe for everyone else.
        ssh = TasteTester::SSH.new(@name)
        ssh << 'file /etc/chef/client.rb'
        user = ssh.run.last.match(/client-(.*)-(taste-tester|test).rb/)
        if user
          user[1]
        else
          nil
        end
      end
    end

    def in_test?
      ssh = TasteTester::SSH.new(@name)
      ssh << 'test -f /etc/chef/test_timestamp'
      if ssh.run.first == 0 && who_is_testing != ENV['USER']
        true
      else
        false
      end
    end

    def keeptesting
      logger.warn("Renewing taste-tester on #{@name} until #{@timestamp}")
      nuke_old_tunnel
      setup_tunnel
    end

    private

    def config
      if TasteTester::Config.use_ssh_tunnels
        url = 'http://localhost:4001'
      else
        url = "http://#{@chef_server}:4000"
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
