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

      # libgit turns out to be *very* slow at this. Using /usr/bin/git
      # for now, we'll circle back to this.
      #
      # def changes(start_ref, end_ref)
      #   @logger.info("Diff between #{start_ref} and #{end_ref}")
      #   diff(start_ref, end_ref).
      #     map do |obj|
      #     {
      #       :path => obj.delta.old_file[:path],
      #       :status => obj.delta.status
      #     }
      #   end
      # end

      # Return files changed between two revisions
      def changes(start_ref, end_ref)
        s = Mixlib::ShellOut.new(
          "#{@bin} diff --name-status #{start_ref} #{end_ref}",
          :cwd => File.expand_path(@repo_path)
        )
        s.run_command.error!
        changes = s.stdout.lines.map do |line|
          # Normal lines are a letter, some space and path, ala:
          # M   foo/bar/baz
          m1 = line.match(/^(\w)\s+(\S+)$/)
          m2 = line.match(/^R(?:\d*)\s+(\S+)\s+(\S+)/)
          if m1
            {
              :status => m1[1] == 'D' ? :deleted : :modified,
              :path => m1[2].sub("#{@repo_path}/", '')
            }
          elsif m2
            # We may run into renames sometimes... they take the form of
            # R<numbers>   path1   path2
            # ala:
            # R050 foo/bar/baz bing/bang/bong
            #
            # I don't know if the number is always there, the man page
            # doesn't mention them, so I don't require them to be there.
            #
            # Anyway, in this case, treat it as if we saw a delete and
            # an add. We're in a map, so we can't just fake an extra iteration,
            # so we'll return an array and then flatten it at the end...
            [
              {
                :status => :deleted,
                :path => m2[1].sub("#{@repo_path}/", '')
              },
              {
                :status => :modified,
                :path => m2[2].sub("#{@repo_path}/", '')
              }
            ]
          else
            # We've seen some weird non-reproducible failures here
            # Report and blow up
            @logger.error(
              'Something went wrong. Please please report this output.'
            )
            @logger.error('Error on:')
            @logger.error(line)
            @logger.error('All files:')
            @logger.error(s.stdout.lines)
            exit 1
          end
        end
        # Handle renames, see big comment above
        changes.flatten
      end

      def update
        cmd = Mixlib::ShellOut.new(
          "#{@bin} pull --rebase", :cwd => File.expand_path(@repo_path)
        )
        cmd.run_command
        if cmd.exitstatus != 0
          @logger.error('Something went wrong with git!')
          @logger.error(cmd.stdout)
          fail
        end
        cmd.stdout
      end

      # Return all files
      def files
        @repo.index.map { |x| { :path => x[:path], :status => :created } }
      end

      def status
        cmd = Mixlib::ShellOut.new(
          "#{@bin} status --porcelain 2>&1",
          :cwd => File.expand_path(@repo_path)
        )
        cmd.run_command
        if cmd.exitstatus != 0
          @logger.error('Something went wrong with git!')
          @logger.error(cmd.stdout)
          fail
        end
        cmd.stdout
      end

      private

      def diff(start_ref, end_ref)
        if end_ref
          @logger.info("Diff between #{start_ref} and #{end_ref}")
          @repo.
            diff(start_ref, end_ref)
        else
          @logger.info("Diff between #{start_ref} and working dir")
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
