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

      def self.info(msg)
        if @@logger
          @@logger.info(msg)
        end
      end

      def self.debug(msg)
        if @@logger
          @@logger.debug(msg)
        end
      end

      def info(msg)
        BetweenMeals::Changes::Change.info(msg)
      end

      def debug(msg)
        BetweenMeals::Changes::Change.debug(msg)
      end
    end
  end
end
