# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
require_relative 'changes'

module BetweenMeals
  # Convenience for dealing with changes
  # Represents a list of diffs between two revisions
  # as a series of Cookbook and Role objects
  #
  # Basically, you always want to use BetweenMeals::Changes through this
  # helper class.
  class Changeset
    def initialize(logger, repo, start_ref, end_ref, locations)
      @logger = logger
      @repo = repo
      @cookbook_dirs = locations[:cookbook_dirs].dup
      @role_dir = locations[:role_dir]
      @databag_dir = locations[:databag_dir]
      # Figure out which files changed if refs provided
      # or return all files (full upload) otherwise
      if start_ref
        @files = []
        @repo.changes(start_ref, end_ref).each do |file|
          @files << file
        end
      else
        @files = @repo.files
      end
    end

    def cookbooks
      BetweenMeals::Changes::Cookbook.find(@files, @cookbook_dirs, @logger)
    end

    def roles
      BetweenMeals::Changes::Role.find(@files, @role_dir, @logger)
    end

    def databags
      BetweenMeals::Changes::Databag.find(@files, @databag_dir, @logger)
    end
  end
end
