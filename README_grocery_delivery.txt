Ohai!

Welcome to grocery_delivery, software to keep cookbooks and roles in sync
between an SVN repo and a chef server. The idea is that if you have multiple,
distinct Chef instances that should all be identical, they can all run this
script in cron. The script uses proper locking, so you should be able to run it
even every minute.

However, there are several things to know:
  * It assumes you don't leverage versions or environments.
  * You want anything committed to HEAD to be uploaded immediately.

To customize grocery_delivery, you can create a file called "gd_local.hooks"
either in the same directory as grocery_delivery, or in /etc, and it can override
a variety of variables and/or define functions which will be called. These hooks
are described here:

VARIABLES
=========

MASTER_PATH - The path where grocery_delivery should keep its SVN checkout and
state files. Defaults to /var/chef/grocery_delivery_work.

REPONAME - The name of the SVN repo. Defaults to ops.

COOKBOOKS_PATH - The relative path to cookbooks from within repo. Defaults to
'chef/cookbooks'

ROLES_PATH - The relative path to roles from within the repo. Defaults to
'chef/roles'

REV_CHECKPOINT - The grocery_delivery state filename (it goes into
$MASTER_PATH). The default is 'gd_revision'

KNIFE_CONFIG - The path to knife config. Defaults to '/root/.chef/knife.rb'

KNIFE - The path to knife. Defaults to '/opt/chef/bin/knife'

FUNCTIONS
=========
gdhook_preflight_checks() - Checks to run before we even parse options. Typically
to check if you even should be running.

gdhook_exit_trap_commands() - This should echo out any commands to be setup up
for an exit trap. grocery_delivery sets up an exit trap to remove its lockfile,
but you may have other things you'd like to do.

gdhook_prerun() - This should do anything you want done right before
grocery_delivery starts doing its work.

gdhook_post_repo_up() - This is called after the repo is created/updated, but
before we talk to the Chef server.

gdhook_postrun() - Things to right after grocery_delivery is done doing its
work.
