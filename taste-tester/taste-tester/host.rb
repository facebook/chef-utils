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
      @timestamp =
      if TasteTester::Config.testing_until
        TasteTester::Config.testing_until.
          strftime('%y%m%d%H%M.%S')
      else
        (Time.now + TasteTester::Config.testing_time).
          strftime('%y%m%d%H%M.%S')
      end
    end

    def runchef
      logger.info "Running '#{TasteTester::Config.command}' on #{@name}"
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
      logger.info "Finished #{TasteTester::Config.command}" +
        " on #{@name} with status #{status}"
      if status == 0
        msg = "#{TasteTester::Config.command} was successful" +
          ' - please log to the host and confirm all the intended' +
          ' changes were made'
        logger.error msg.upcase
      end
    end

    def test
      logger.info "Taste-testing on #{@name}"
      ssh = TasteTester::SSH.new(@name)
      ssh << 'logger -t taste-tester Moving server into taste-tester' +
        " for #{@user}"
      ssh << "touch -t #{@timestamp} /etc/chef/test_timestamp"
      ssh << "echo '#{@serialized_config}' | base64 --decode --ignore-garbage" +
        " > /etc/chef/client-#{@user}-taste-tester.rb"
      ssh << 'rm -vf /etc/chef/client.rb'
      ssh << "ln -vs /etc/chef/client-#{@user}-taste-tester.rb" +
        ' /etc/chef/client.rb'
      ssh.run!
      cmds = TasteTester::Hooks.test_remote_cmds(TasteTester::Config.dryrun,
                                                 @name)
      if cmds && cmds.any?
        ssh = TasteTester::SSH.new(@name)
        cmds.each { |c| ssh << c }
        ssh.run!
      end
    end

    def untest
      logger.info "Removing #{@name} from taste-tester"
      ssh = TasteTester::SSH.new(@name)
      ssh << 'rm -vf /etc/chef/client.rb'
      ssh << "rm -vf /etc/chef/client-#{@user}-taste-tester.rb"
      ssh << 'ln -vs /etc/chef/client-prod.rb /etc/chef/client.rb'
      ssh << 'rm -vf /etc/chef/client.pem'
      ssh << 'ln -vs /etc/chef/client-prod.pem /etc/chef/client.pem'
      ssh << 'rm -vf /etc/chef/test_timestamp'
      ssh << 'logger -t taste-tester Returning server to production'
      ssh.run!
    end

    def who_is_testing
      ssh = TasteTester::SSH.new(@name)
      ssh << 'file /etc/chef/client.rb'
      # -test is the old filename, remove this at some point
      user = ssh.run.last.match(/client-(.*)-(taste-tester|test).rb/)
      if user
        user[1]
      else
        nil
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
      logger.info "Renewing taste-tester on #{@name} until #{@timestamp}"
      ssh = TasteTester::SSH.new(@name)
      ssh << "touch -t #{@timestamp} /etc/chef/test_timestamp"
      ssh.run!
    end

    private

    def config
      ttconfig = <<-eos
# TasteTester by #{@user}
# Prevent people from screwing up their permissions
if Process.euid != 0
  puts 'Please run chef as root!'
  Process.exit!
end

log_level                :info
log_location             STDOUT
chef_server_url          'http://#{@chef_server}:4000'
json_attribs             '/etc/chef/run-list.json'
Ohai::Config[:plugin_path] << '/etc/chef/ohai_plugins'

      eos
      ttconfig += <<-eos
puts 'INFO: Running on #{@name} in taste-tester by #{@user}'
      eos
      return ttconfig
    end
  end
end
