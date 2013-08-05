Ohai!

Welcome to grocery_delivery, software to keep cookbooks and roles in sync
between a VCS repo and a chef server. The idea is that if you have multiple,
distinct Chef instances that should all be identical, they can all run this
script in cron. The script uses proper locking, so you should be able to run it
even every minute.

However, there are several things to know:
  * It assumes you don't leverage versions or environments.
  * You want anything committed to HEAD to be uploaded immediately.

To customize grocery_delivery, you can create a file called "gd_local.hooks"
either in the same directory as grocery_delivery, a subdirectory of
grocery_delivery's directory called "gd_hooks", or in /etc, and it can
override a variety of variables and/or define functions which will be called.
These hooks are described here:

VARIABLES
=========
MASTER_PATH - The path where grocery_delivery should keep its VCS checkout and
state files. Defaults to /var/chef/grocery_delivery_work.

REPONAME - The name of the VCS repo - i.e. the subdir of MASTER_PATH to check out the repo to. Defaults to ops.

REPO_URL - The URL for the initial checkout if the repository if it does not
already exist.

COOKBOOK_PATHS - The relative path to cookbooks from within repo. Defaults to
an array of ('chef/cookbooks'). You can have multiple entries. If you have directories that are subdirectories of others, it'll handle this intelligently.

ROLES_PATH - The relative path to roles from within the repo. Defaults to
'chef/roles'

REV_CHECKPOINT - The grocery_delivery state filename (it goes into
$MASTER_PATH). The default is 'gd_revision'

KNIFE_CONFIG - The path to knife config. Defaults to '/root/.chef/knife.rb'

KNIFE - The path to knife. Defaults to '/opt/chef/bin/knife'

VCS - The revision control system to use. This should be the full path to
the client such as '/usr/bin/svn' or '/usr/bin/git'. See "VCS SUPPORT" below
for more details.

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

VCS SUPPORT
===========
Grocery_delivery's VCS support has been abstracted into plugable modules. Two plugins are distributed: git and svn. To choose one, in your local hook file you can define a variable called $VCS to the path to your VCS sytem.

Note that if you need to, each VCS module also has a variable you can set
to override the underlying binary that will be called. In the Subversion module this is $SVN, and in the Git module it's GIT. These default to the value of $VCS, but
since the module loaded depends on this variable, and you may need to then do more interesting things, you can give $SVN/$GIT a more specific value.
