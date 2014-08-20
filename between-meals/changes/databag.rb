# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
# rubocop:disable ClassVars

module BetweenMeals
  module Changes
    # Changeset aware databag
    class Databag < Change
      attr_accessor :item
      def self.name_from_path(path, databag_dir)
        re = %r{^#{databag_dir}/([^/]+)/([^/]+)\.json}
        debug("[databag] Matching #{path} against #{re}")
        m = path.match(re)
        if m
          info("Databag is #{m[1]} item is #{m[2]}")
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
        return [] if list.nil? || list.empty?
        list.
          select { |x| self.name_from_path(x[:path], databag_dir) }.
          map do |x|
            BetweenMeals::Changes::Databag.new(x, databag_dir)
          end
      end
    end
  end
end
