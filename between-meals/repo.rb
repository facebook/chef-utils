# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'mixlib/shellout'

module BetweenMeals
  # Local checkout wrapper
  class Repo
    attr_reader :repo_path
    attr_writer :bin

    def initialize(repo_path, logger)
      @repo_path = repo_path
      @logger = logger
      @repo = nil
      @bin = nil
      setup
    rescue
      @logger.warn("Unable to read repo from #{File.expand_path(repo_path)}")
      exit(1)
    end

    def self.get(type, repo_path, logger)
      case type
      when 'svn'
        require_relative 'repo/svn'
        BetweenMeals::Repo::Svn.new(repo_path, logger)
      when 'git'
        require_relative 'repo/git'
        BetweenMeals::Repo::Git.new(repo_path, logger)
      else
        fail "Do not know repo type #{type}"
      end
    end

    def exists?
      fail 'Not implemented'
    end

    def status
      fail 'Not implemented'
    end

    def setup
      fail 'Not implemented'
    end

    def head_rev
      fail 'Not implemented'
    end

    def head_msg
      fail 'Not implemented'
    end

    def head_msg=
      fail 'Not implemented'
    end

    def head_parents
      fail 'Not implemented'
    end

    def latest_revision
      fail 'Not implemented'
    end

    def create(_url)
      fail 'Not implemented'
    end

    # Return files changed between two revisions
    def changes(_start_ref, _end_ref)
      fail 'Not implemented'
    end

    def update
      fail 'Not implemented'
    end

    # Return all files
    def files
      fail 'Not implemented'
    end
  end
end
