# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
# rubocop:disable UnusedMethodArgument

require_relative 'logging'

module TasteTester
  # Hooks placeholders
  class Hooks
    extend TasteTester::Logging
    extend BetweenMeals::Util

    # Do stuff before we upload to chef-zero
    def self.pre_upload(dryrun, repo, last_ref, cur_ref)
    end

    # Do stuff after we upload to chef-zero
    def self.post_upload(dryrun, repo, last_ref, cur_ref)
    end

    # Do stuff before we put hosts in test mode
    def self.pre_test(dryrun, repo, hosts)
    end

    # This should return an array of commands to execute on
    # remote systems.
    def self.test_remote_cmds(dryrun, hostname)
    end

    # Do stuff after we put hosts in test mode
    def self.post_test(dryrun, repo, hosts)
    end

    # Additional checks you want to do on the repo
    def self.repo_checks(dryrun, repo)
    end

    def self.get(file)
      path = File.expand_path(file)
      logger.info("Loading plugin at #{path}")
      unless File.exists?(path)
        logger.error('Plugin file not found')
        exit(1)
      end
      class_eval(File.read(path), __FILE__, __LINE__)
    end
  end
end
