# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
# rubocop:disable ClassVars

module BetweenMeals
  module Changes
    # Changeset aware cookbook
    class Cookbook < Change
      def self.meaningful_cookbook_file?(path, cookbook_dirs)
        cookbook_dirs.each do |dir|
          re = %r{^#{dir}/([^/]+)/.*}
          m = path.match(re)
          debug("[cookbook] #{path} meaningful? [#{re}]: #{m}")
          return true if m
        end
        false
      end

      def self.explode_path(path, cookbook_dirs)
        cookbook_dirs.each do |dir|
          re = %r{^#{dir}/([^/]+)/.*}
          debug("[cookbook] Matching #{path} against ^#{re}")
          m = path.match(re)
          next unless m
          info("Cookbook is #{m[1]}")
          return {
            :cookbook_dir => dir,
            :name => m[1] }
        end
        nil
      end

      def initialize(files, cookbook_dirs)
        @files = files
        @name = self.class.explode_path(
          files.sample[:path],
          cookbook_dirs
        )[:name]
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
        return [] if list.nil? || list.empty?
        # rubocop:disable MultilineBlockChain
        list.
          group_by do |x|
          # Group by prefix of cookbok_dir + cookbook_name
          # so that we treat deletes and modifications across
          # two locations separately
          g = self.explode_path(x[:path], cookbook_dirs)
          g[:cookbook_dir] + '/' + g[:name] if g
        end.
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
        # rubocop:enable MultilineBlockChain
      end
    end
  end
end
