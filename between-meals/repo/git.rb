# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'rugged'
require 'mixlib/shellout'

module BetweenMeals
  # Local checkout wrapper
  class Repo
    # Git provider
    class Git < BetweenMeals::Repo
      def setup
        @repo = Rugged::Repository.new(File.expand_path(@repo_path))
        @bin = 'git'
      end

      def exists?
        @repo && !@repo.empty?
      end

      def head_rev
        @repo.head.target.oid
      end

      def last_msg
        @repo.head.target.message
      end

      def last_msg=(msg)
        @repo.head.target.amend(
          {
            :message => msg,
            :update_ref => 'HEAD',
          }
        )
      end

      def last_author
        @repo.head.target.to_hash[:author]
      end

      def head_parents
        @repo.head.target.parents
      end

      def checkout(url)
        s = Mixlib::ShellOut.new("#{@bin} clone #{url} #{@repo}").run_command
        s.error!
      end

      # Return files changed between two revisions
      def changes(start_ref, end_ref)
        @logger.debug("Diff between #{start_ref} and #{end_ref}")
        diff(start_ref, end_ref).
          map do |obj|
          {
            :path => obj.delta.old_file[:path],
            :status => obj.delta.status
          }
        end
      end

      # Return all files
      def files
        @repo.index.map { |x| { :path => x[:path], :status => :created } }
      end

      def status
        cmd = Mixlib::ShellOut.new(
          'git status --porcelain 2>&1',
          :cwd => File.expand_path(@repo_path)
        )
        cmd.run_command
        if cmd.exitstatus != 0
          logger.error('Something went wrong with git!')
          logger.error(cmd.stdout)
          fail
        end
        cmd.stdout
      end

      private

      def diff(start_ref, end_ref)
        if end_ref
          @logger.debug("Diff between #{start_ref} and #{end_ref}")
          @repo.
            diff(start_ref, end_ref)
        else
          @logger.debug("Diff between #{start_ref} and working dir")
          @repo.
            diff_workdir(
              start_ref,
              :include_untracked => true,
              :recurse_untracked_dirs => true
            )
        end
      end
    end
  end
end
