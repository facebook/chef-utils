# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require_relative '../repo'
require 'mixlib/shellout'

module BetweenMeals
  # Local checkout wrapper
  class Repo
    # SVN implementation
    class Svn < BetweenMeals::Repo
      def setup
        @bin = 'svn'
      end

      def exists?
        # this shuold be better
        Dir.exists?(@repo_path)
      end

      def head
        s = Mixlib::ShellOut.new("#{@bin} info #{@repo_path}").run_command
        s.error!
        s.stdout.each_line do |line|
          m = line.match(/Last Changed Rev: (\d+)$/)
          return m[1] if m
        end
      end

      def latest_revision
        s = Mixlib::ShellOut.new("#{@bin} info #{@repo_path}").run_command
        s.error!
        s.stdout.each do |line|
          m = line.match(/Revision: (\d+)$/)
          return m[1] if m
        end
      end

      def checkout(url)
        s = Mixlib::ShellOut.new(
          "#{@bin} co --ignore-externals #{url} #{@repo_path}").run_command
        s.error!
      end

      # Return files changed between two revisions
      def changes(start_ref, end_ref)
        s = Mixlib::ShellOut.new(
          "#{@bin} diff -r #{start_ref}:#{end_ref} --summarize #{@repo_path}")
        s.run_command.error!
        @logger.debug("Diff between #{start_ref} and #{end_ref}")
        s.stdout.lines.map do |line|
          m = line.match(/^(\w)\s+(\S+)$/)
          {
            :status => m[1] == 'D' ? :deleted : :modified,
            :path => m[2].sub("#{@repo_path}/", '')
          }
        end
      end

      def update
        cleanup
        revert
        up
      end

      # Return all files
      def files
        s = Mixlib::ShellOut.new("#{@bin} ls --depth infinity #{@repo_path}")
        s.run_command
        s.error!
        s.stdout.split("\n").map do |x|
          { :path => x, :status => :created }
        end
      end

      private

      def run(cmd)
        Mixlib::ShellOut.new(cmd).run_command.error!
      end

      def revert
        run("#{@bin} revert -R #{@repo_path}")
      end

      def up
        run("#{@bin} update #{@repo_path}")
      end

      def cleanup
        run("#{@bin} cleanup #{@repo_path}")
      end

      def first_revision
        0
      end
    end
  end
end
