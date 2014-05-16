# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require_relative 'logging'
require_relative '../../between-meals/util'

module TasteTester
  # Hooks placeholders
  class Hooks
    extend TasteTester::Logging
    extend BetweenMeals::Util

    # Do stuff before we upload to chef-zero
    def self.pre_upload(_dryrun, _repo, _last_ref, _cur_ref)
    end

    # Do stuff after we upload to chef-zero
    def self.post_upload(_dryrun, _repo, _last_ref, _cur_ref)
    end

    # Do stuff before we put hosts in test mode
    def self.pre_test(_dryrun, _repo, _hosts)
    end

    # This should return an array of commands to execute on
    # remote systems.
    def self.test_remote_cmds(_dryrun, _hostname)
    end

    # Should return a string with extra stuff to shove
    # in the remote client.rb
    def self.test_remote_client_rb_extra_code(_hostname)
    end

    # Do stuff after we put hosts in test mode
    def self.post_test(_dryrun, _repo, _hosts)
    end

    # Additional checks you want to do on the repo
    def self.repo_checks(_dryrun, _repo)
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
