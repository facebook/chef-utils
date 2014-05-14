# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
# rubocop:disable UnusedBlockArgument, UnusedMethodArgument

require_relative 'server'
require_relative 'host'
require_relative 'config'
require_relative 'client'
require_relative 'logging'

module TasteTester
  # Functionality dispatch
  module Commands
    extend TasteTester::Logging

    def self.start
      server = TasteTester::Server.new
      return if TasteTester::Server.running?
      server.start
    end

    def self.restart
      server = TasteTester::Server.new
      server.stop if TasteTester::Server.running?
      server.start
    end

    def self.stop
      server = TasteTester::Server.new
      server.stop
    end

    def self.status
      server = TasteTester::Server.new
      if TasteTester::Server.running?
        logger.info("Local taste-tester server running on port #{server.port}")
        if server.latest_uploaded_ref
          logger.info('Latest uploaded revision is ' +
            server.latest_uploaded_ref)
        else
          logger.info('No cookbooks/roles uploads found')
        end
      else
        logger.info('Local taste-tester server not running')
      end
    end

    def self.test
      hosts = TasteTester::Config.servers
      unless hosts
        logger.info('You must provide a hostname')
        exit(1)
      end
      unless TasteTester::Config.yes
        printf("Set #{TasteTester::Config.servers} to test mode? [y/N] ")
        ans = STDIN.gets.chomp
        exit(1) unless ans =~ /^[yY](es)?$/
      end
      if TasteTester::Config.linkonly && TasteTester::Config.really
        logger.info('Skipping upload at user request... potentially dangerous!')
      else
        if TasteTester::Config.linkonly
          logger.warn('Ignoring --linkonly because --really not set')
        end
        upload
      end
      server = TasteTester::Server.new
      repo = BetweenMeals::Repo.get(TasteTester::Config.repo_type,
                                    TasteTester::Config.repo, logger)
      unless TasteTester::Config.skip_pre_test_hook
        TasteTester::Hooks.pre_test(TasteTester::Config.dryrun, repo, hosts)
      end
      tested_hosts = []
      hosts.each do |hostname|
        host = TasteTester::Host.new(hostname, server)
        if host.in_test?
          username = host.who_is_testing
          logger.error("User #{username} is already testing on #{hostname}")
        else
          host.test
          tested_hosts << hostname
        end
      end
      unless TasteTester::Config.skip_post_test_hook
        TasteTester::Hooks.post_test(TasteTester::Config.dryrun, repo,
                                     tested_hosts)
      end
    end

    def self.untest
      hosts = TasteTester::Config.servers
      unless hosts
        logger.info('You must provide a hostname')
        exit(1)
      end
      server = TasteTester::Server.new
      hosts.each do |hostname|
        host = TasteTester::Host.new(hostname, server)
        host.untest
      end
    end

    def self.runchef
      hosts = TasteTester::Config.servers
      unless hosts
        logger.info('You must provide a hostname')
        exit(1)
      end
      server = TasteTester::Server.new
      hosts.each do |hostname|
        host = TasteTester::Host.new(hostname, server)
        host.run
      end
    end

    def self.keeptesting
      hosts = TasteTester::Config.servers
      unless hosts
        logger.info('You must provide a hostname')
        exit(1)
      end
      server = TasteTester::Server.new
      hosts.each do |hostname|
        host = TasteTester::Host.new(hostname, server)
        host.keeptesting
      end
    end

    def self.upload
      server = TasteTester::Server.new
      # On a fore-upload rather than try to clean up whatever's on the server
      # we'll restart chef-zero which will clear everything and do a full
      # upload
      if TasteTester::Config.force_upload
        server.restart
      else
        server.start unless TasteTester::Server.running?
      end
      client = TasteTester::Client.new(server)
      client.skip_checks = true if TasteTester::Config.skip_checks
      client.force = true if TasteTester::Config.force_upload
      client.upload
    end
  end
end
