# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
# rubocop:disable ClassVars


module BetweenMeals
  # A set of classes that represent a given item's change (a cookbook
  # that's changed, a role that's changed or a databag item that's changed).
  #
  # You almost certainly don't want to use this directly, and instead want
  # BetweenMeals::Changeset
  module Changes
    # Common functionality
    class Change
      @@logger = nil
      attr_accessor :name, :status
      def to_s
        @name
      end

      # People who use us through find() can just pass in logger,
      # for everyone else, here's a setter
      def logger=(log)
        @@logger = log
      end

      def self.debug(msg)
        if @@logger
          @@logger.debug(msg)
        end
      end

      def debug(msg)
        BetweenMeals::Changes::Change.debug(msg)
      end
    end

    # Changeset aware cookbook
    class Cookbook < Change
      def self.meaningful_cookbook_file?(path, cookbook_dirs)
        cookbook_dirs.each do |dir|
          re = %r{^#{dir}/([^/]+)/.*/.*}
          m = path.match(re)
          debug("[cookbook] #{path} meaningful? [#{re}]: #{m}")
          return true if m
        end
        false
      end

      def self.name_from_path(path, cookbook_dirs)
        cookbook_dirs.each do |dir|
          re = %r{^#{dir}/([^/]+)/.*}
          debug("[cookbook] Matching #{path} against ^#{re}")
          m = path.match(re)
          next unless m
          debug("Cookbook is #{m[1]}")
          return m[1]
        end
        nil
      end

      def initialize(files, cookbook_dirs)
        @files = files
        @name = self.class.name_from_path(files.sample[:path], cookbook_dirs)
        # if metadata.rb is being deleted
        #   cookbook is marked for deletion
        # otherwise it was modified
        #   and will be re-uploaded
        if files.
          select { |x| x[:status] == :deleted }.
          map { |x| x[:path].match(%{.*metadata\.rb$}) }.
          compact.
          any?
          @status = :deleted
        else
          @status = :modified
        end
      end

      # Given a list of changed files
      # create a list of Cookbook objects
      def self.find(list, cookbook_dirs, logger)
        @@logger = logger
        list.
          group_by { |x| self.name_from_path(x[:path], cookbook_dirs) }.
          map do |_, change|
            # Confirm we're dealing with a cookbook
            # Changes to OWNERS or other stuff that might end up
            # in [core, other, secure] dirs are ignored
            is_cookbook = change.select do |c|
              self.meaningful_cookbook_file?(c[:path], cookbook_dirs)
            end.any?
            if is_cookbook
              BetweenMeals::Changes::Cookbook.new(change, cookbook_dirs)
            end
          end.compact
      end
    end

    # Changeset aware role
    class Role < Change
      def self.name_from_path(path, role_dir)
        re = "^#{role_dir}\/(.+)\.rb"
        debug("[role] Matching #{path} against #{re}")
        m = path.match(re)
        if m
          debug("Name is #{m[1]}")
          return m[1]
        end
        nil
      end

      def initialize(file, role_dir)
        @status = file[:status] == :deleted ? :deleted : :modified
        @name = self.class.name_from_path(file[:path], role_dir)
      end

      # Given a list of changed files
      # create a list of Role objects
      def self.find(list, role_dir, logger)
        @@logger = logger
        list.
          select { |x| self.name_from_path(x[:path], role_dir) }.
          map do |x|
            BetweenMeals::Changes::Role.new(x, role_dir)
          end
      end
    end

    # Changeset aware databag
    class Databag < Change
      attr_accessor :item
      def self.name_from_path(path, databag_dir)
        re = %r{^#{databag_dir}/([^/]+)/([^/]+)\.json}
        debug("[databag] Matching #{path} against #{re}")
        m = path.match(re)
        if m
          debug("Databag is #{m[1]} item is #{m[2]}")
          return m[1], m[2]
        end
        nil
      end

      def initialize(file, databag_dir)
        @status = file[:status]
        @name, @item = self.class.name_from_path(file[:path], databag_dir)
      end

      def self.find(list, databag_dir, logger)
        @@logger = logger
        list.
          select { |x| self.name_from_path(x[:path], databag_dir) }.
          map do |x|
            BetweenMeals::Changes::Databag.new(x, databag_dir)
          end
      end
    end
  end
end
