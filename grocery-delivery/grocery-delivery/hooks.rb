# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

module GroceryDelivery
  # Hook class for GD
  class Hooks
    # This code will run once we've read our config and loaded our plugins
    # but before *anything* else. We don't even have a lock yet.
    def self.preflight_checks(_dryrun)
    end

    # This is run after we've gotten a lock, written a pidfile and initialized
    # our repo object (but not touched the repo yet)
    def self.prerun(_dryrun)
    end

    # This is code to run after we've updated the repo, but before we've done
    # any work to parse it.
    def self.post_repo_up(_dryrun)
    end

    # After we parse the updates to the repo and uploaded/deleted the relevent
    # items from the local server.
    def self.postrun(_dryrun, _success, _msg)
    end

    # exit hooks.
    def self.atexit(_dryrun, _success, _msg)
    end

    def self.get(file)
      class_eval(File.read(file), __FILE__, __LINE__) if File.exists?(file)
    end
  end
end
