# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'rugged'
require 'mixlib/shellout'
require_relative '../changeset'

module BetweenMeals
  # Local checkout wrapper
  class Repo
    # Git provider
    class Git < BetweenMeals::Repo
      def setup
        if File.exists?(File.expand_path(@repo_path))
          @repo = Rugged::Repository.new(File.expand_path(@repo_path))
        else
          @repo = nil
        end
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
        s = Mixlib::ShellOut.new(
          "#{@bin} clone #{url} #{@repo} #{@repo_path}"
        ).run_command
        s.error!
        @repo = Rugged::Repository.new(File.expand_path(@repo_path))
      end

      # Return files changed between two revisions
      def changes(start_ref, end_ref)
        check_refs(start_ref, end_ref)
        s = Mixlib::ShellOut.new(
          "#{@bin} diff --name-status #{start_ref} #{end_ref}",
          :cwd => File.expand_path(@repo_path)
        )
        s.run_command.error!
        begin
          parse_status(s.stdout).compact
        rescue => e
          # We've seen some weird non-reproducible failures here
          @logger.error(
            'Something went wrong. Please please report this output.'
          )
          @logger.error(e)
          s.stdout.lines.each do |line|
            @logger.error(line.strip)
          end
          exit(1)
        end
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

      def check_refs(start_ref, end_ref)
        unless @repo.exists?(start_ref)
          fail Changeset::ReferenceError
        end
        unless end_ref.nil?
          unless @repo.exists?(end_ref)
            fail Changeset::ReferenceError
          end
        end
      end

      def parse_status(changes)
        # man git-diff-files
        # Possible status letters are:
        #
        # A: addition of a file
        # C: copy of a file into a new one
        # D: deletion of a file
        # M: modification of the contents or mode of a file
        # R: renaming of a file
        # T: change in the type of the file
        # U: file is unmerged (you must complete the merge before it can
        #    be committed)
        # X: "unknown" change type (most probably a bug, please report it)

        # rubocop:disable MultilineBlockChain
        changes.lines.map do |line|
          case line
          when /^A\s+(\S+)$/
            # A path
            {
              :status => :modified,
              :path => Regexp.last_match(1)
            }
          when /^C(?:\d*)\s+(\S+)\s+(\S+)/
            # C<numbers> path1 path2
            {
              :status => :modified,
              :path => Regexp.last_match(2)
            }
          when /^D\s+(\S+)$/
            # D path
            {
              :status => :deleted,
              :path => Regexp.last_match(1)
            }
          when /^M(?:\d*)\s+(\S+)$/
            # M<numbers> path
            {
              :status => :modified,
              :path => Regexp.last_match(1)
            }
          when /^R(?:\d*)\s+(\S+)\s+(\S+)/
            # R<numbers> path1 path2
            [
              {
                :status => :deleted,
                :path => Regexp.last_match(1)
              },
              {
                :status => :modified,
                :path => Regexp.last_match(2)
              }
            ]
          when /^T\s+(\S+)$/
            # T path
            [
              {
                :status => :deleted,
                :path => Regexp.last_match(1)
              },
              {
                :status => :modified,
                :path => Regexp.last_match(1)
              }
            ]
          else
            fail 'No match'
          end
        end.flatten.map do |x|
          {
            :status => x[:status],
            :path => x[:path].sub("#{@repo_path}/", '')
          }
        end
        # rubocop:enable MultilineBlockChain
      end
    end
  end
end
