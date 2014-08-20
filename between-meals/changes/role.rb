# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
# rubocop:disable ClassVars

module BetweenMeals
  module Changes
    # Changeset aware role
    class Role < Change
      def self.name_from_path(path, role_dir)
        re = "^#{role_dir}\/(.+)\.rb"
        debug("[role] Matching #{path} against #{re}")
        m = path.match(re)
        if m
          info("Name is #{m[1]}")
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
        return [] if list.nil? || list.empty?
        list.
          select { |x| self.name_from_path(x[:path], role_dir) }.
          map do |x|
            BetweenMeals::Changes::Role.new(x, role_dir)
          end
      end
    end
  end
end
