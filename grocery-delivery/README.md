# Grocery Delivery

## Intro
Ohai!

Welcome to Grocery Delivery, software to keep cookbooks, roles, and databags in
sync between a VCS repo and a chef server. The idea is that if you have
multiple, distinct Chef server instances that should all be identical, they can
all run this script in cron. The script uses proper locking, so you should be
able to run it every minute.

However, there are several things to know:
* It assumes you don't leverage versions or environments.
* It assumes you want anything committed to HEAD to be uploaded immediately.

Grocery Delivery is pretty customizable. Many things can be tuned from a simple
config file, and it's pluggable so you can extend it as well.

## Prerequisites

Grocery Delivery is a particular way of managing your Chef infrastructure,
and it assumes you follow that model consistently. Here are the basic
principals:

* Checkins are live immediately (which implies code review before merge)
* Versions are meaningless (ideally, never change them)
* You want all your chef-servers in sync
* Everything you care about comes from version control.

We recommend using the whitelist_node_attrs
(https://github.com/opscode/whitelist-node-attrs) cookbook to prevent node
attributes being saved back to the server. Or in recent versions of Chef 11,
this feature is built-in:

http://docs.getchef.com/essentials_node_object.html#whitelist-attributes

## Dependencies

* Mixlib::Config
* BetweenMeals

## Config file

The default config file is `/etc/gd-config.rb` but you may use -c to specify
another. The config file works the same as client.rb does for Chef - there
are a series of keywords that take an arguement and anything else is just
standard Ruby.

All command-line options are available in the config file:
* dry_run (bool, default: false)
* debug (bool, default: false)
* timestamp (bool, default: false)
* config_file (string, default: `/etc/gd-config.rb`)
* lockfile (string, default: `/var/lock/subsys/grocery_delivery`)
* pidfile (string, default: `/var/run/grocery_delivery.pid`)

In addition the following are also available:
* master_path - The top-level path for Grocery Delivery's work. Most other
  paths are relative to this. Default: `/var/chef/grocery_delivery_work`
* repo_url - The URL to clone/checkout if it doesn't exist. Default: `nil`
* reponame - The relative directory to check the repo out to, inside of
  `master_path`. Default: `ops`
* cookbook_paths - An array of directories that contain cookbooks relative to
  `reponame`. Default: `['chef/cookbooks']`
* role_path - A directory to find roles in relative to `reponame`. Default:
  `['chef/roles']`
* databag_path - A directory to find databags in relative to `reponame`.
  Default: `['chef/databags']`
* rev_checkpoint - Name of the file to store the last-uploaded revision,
  relative to `reponame`. Default: `gd_revision`
* knife_config - Knife config to use for uploads. Default:
  `/root/.chef/knife.rb`
* knife_bin - Path to knife. Default: `/opt/chef/bin/knife`
* vcs_type - Git or SVN? Default: `svn`
* vcs_path - Path to git or svn binary. If not given, just uses 'git' or 'svn'.
  Default: `nil`
* plugin_path - Path to plugin file. Default: `/etc/gd-plugin.rb`

## Plugin

The plugin should be a ruby file which defines several class methods. It is
class_eval()d into a Hooks class.

The following functions can optionally be defined:

* self.preflight_checks(dryrun)

This code will run once we've read our config and loaded our plugins but before
*anything* else. We don't even have a lock yet. `Dryrun` is a bool which
indicates if we are in dryrun mode.

* self.prerun(dryrun)

This is run after we've gotten a lock, written a pidfile and initialized our
repo object (but not touched the repo yet)

* self.post_repo_up(dryrun)

This is code to run after we've updated the repo, but before we've done any work
to parse it.

* self.postrun(dryrun, success, msg)

After we've parsed the updates to the repo and uploaded/deleted the relevent
items from the local server. `Success` is a bool for whether we succeeded, and
`msg` is the status message - either the revision we sync'd or an error.

* self.atexit(dryrun, success, msg)

Same as postrun, but is registered as an atexit function so it happens even
if we crash.
