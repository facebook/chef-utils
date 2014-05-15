# Taste-tester

## Intro
Ohai!

Welcome to taste-tester, software to manage a chef-zero instance and use it to
test changes on production servers.

At it's core, taste-tester starts up a chef-zero server on localhost, uploads a
repository to it, ssh's to a remote server and points it's configs to your new
chef-zero instance.

Further, it keeps track of where in git you were when that happened so future
uploads will do the right thing, even as you switch branches.

Taste-tester can be controlled via a variety of config-file options, and can be
further customized by writing a plugin.

## Synopsis

Typical usage is:

```text
vi cookbooks/...             # Make your changes and commit locally
taste-tester test -s [host]  # Put host in taste-tester mode
ssh root@[host]              # Log in to host
  # Run chef and watch it break
vi cookbooks/...             # Fix your cookbooks
taste-tester upload          # Upload the diff
ssh root@[host]
  # Run chef and watch it succeed
<Verify your changes were actually applied as intended!>
taste-tester untest [host]   # Put host back in production
                             #   (optional - will revert itself after 1 hour)
```

See the help for futher information.

## Prerequisites

* Taste-tester assumes that /etc/chef/client.rb on your servers is a symlink and
that your real config is /etc/chef/client-prod.rb

* Taste-tester assumes that it's generally safe to "go back" to production. I.e.
We set things up so you can set a cronjob to un-taste-test a server after the
desired amount of time, which means it must be (relatively) safe to revert
back.

* Taste-tester assumes you use a setup similar to grocery-delivery in
production. Specifically that you don't use versions or environments. 

## Automatic Untesting

Taste-tester touches `/etc/chef/test_timestamp` on the remote server as far into
the future as the user wants to test (default is 1h). You should have a cronjob
to check the timestamp of this file, and if it is old, remove it and put the
symlinks for /etc/chef/client.rb back to where they belong.

A small shell script to do this is included called `taste-untester`. We
recommend running this at least every 15 minutes.

## Config file

The default config file is `/etc/taste-tester-config.rb` but you may use -c to
specify another. The config file works the same as client.rb does for Chef -
there are a series of keywords that take an arguement and anything else is just
standard Ruby.

All command-line options are available in the config file:
* debug (bool, default: `false`)
* timestamp (bool, default: `false`)
* config_file (string, default: `/etc/gd-config.rb`)
* plugin_path (string, default: `/etc/taste-tester-plugin.rb`)
* repo (string, default: `#{ENV['HOME']}/ops`)
* testing_time (int, default: `3600`)
* chef_client_command (strng, default: `chef-client`)
* skip_repo_checks (bool, default: `false`)
* skip_pre_upload_hook (bool, default: `false`)
* skip_post_upload_hook (bool, default: `false`)
* skip_pre_test_hook (bool, default: `false`)
* skip_post_test_hook (bool, default: `false`)
* skip_repo_checks_hook (bool, default: `false`)

The following options are also available:
* base_dir - The directory in the repo under which to find chef configs.
Default: `chef`
* cookbook_dirs - An array of cookbook directories relative to base_dir.
Default: `['cookbooks']
* role_dir - A directory of roles, relative to base_dir. Default: `roles`
* databag_dir - A directory of roles, relative to base_dir. Default: `databags`
* ref_file - The file to store the last git revision we uploaded in. Default:
`#{ENV['HOME']}/.chef/taste-tester-ref.txt`
* checksum_dir - The checksum directory to put in knife.conf for users. Default:
`#{ENV['HOME']}/.chef/checksums`

## Plugin

The plugin should be a ruby file which defines several class methods. It is
class_eval()d into a Hooks class.

The following functions can optionally be defined:

* self.pre_upload(dryrun, repo, last_ref, cur_ref)

Stuff to do before we upload anything to chef-zero. `Repo` is a BetweenMeals::Repo
object. `last_ref` is the last git ref we uploaded and `cur_ref` is the git ref
the repo is currently at,

* self.post_upload(dryrun, repo, last_ref, cur_ref)

Stuff to do after we upload to chef-zero.

* self.pre_test(dryrun, repo, hosts)

Stuff to do before we put machines in test mode. `hosts` is an array of
hostnames.

* self.test_remote_cmds(dryrun, hostname)

Additional commands to run on the remote host when putting it in test mode.
Should return an array of strongs. `hostname` is the hostname.

* self.post_test(dryrun, repo, hosts)

Stuff to do after putting all hosts in test mode.

* self.repo_checks(dryrun, repo)

Additional checks you want to do on the repo as sanity checks.
