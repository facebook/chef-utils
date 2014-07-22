# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'mixlib/config'
require 'logger'

module GroceryDelivery
  # Config file parser and config object
  # Uses Mixlib::Config v1 syntax so it works in Chef10 omnibus...
  # it's compatible with v2, so it should work in 11 too.
  class Config
    extend Mixlib::Config

    dry_run false
    verbosity Logger::WARN
    timestamp false
    config_file '/etc/gd-config.rb'
    pidfile '/var/run/grocery_delivery.pid'
    lockfile '/var/lock/subsys/grocery_delivery'
    master_path '/var/chef/grocery_delivery_work'
    repo_url nil
    reponame 'ops'
    cookbook_paths ['chef/cookbooks']
    role_path 'chef/roles'
    databag_path 'chef/databags'
    rev_checkpoint 'gd_revision'
    knife_config '/root/.chef/knife.rb'
    knife_bin '/opt/chef/bin/knife'
    vcs_type 'svn'
    vcs_path nil
    plugin_path '/etc/gd-plugin.rb'
  end
end
