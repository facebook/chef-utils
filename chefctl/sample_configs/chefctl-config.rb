# Copyright 2013-present Facebook
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This config file is located at /etc/chefctl-config.rb
# You can change this location by passing `-C/--config` to `chefctl`
# Default options and descriptions are in comments below.

# Allow the chef run to provide colored output.
# color false

# Whether or not chefctl should provide verbose output.
# verbose false

# The chef-client process to use.
# chef_client '/opt/chef/bin/chef-client'

# Whether or not chef-client should provide debug output.
# debug false

# Default options to pass to chef-client.
# chef_options ['--no-fork']

# Whether or not to provide human-readable output.
# human false

# If set, ignore the splay and stop pending chefctl processes before
# running. This is intended for interactive runs of chef
# (i.e. started by a human).
# immediate false

# The lock file to use for chefctl.
# lock_file '/var/lock/subsys/chefctl'

# How long to wait for the lock to become available.
# lock_time 1800

# Directory where per-run chef logs should be placed.
# log_dir '/var/chef/outputs'

# If set, will not copy chef log to stdout.
# quiet false

# The default splay to use. Ignored if `immediate` is set to true.
# splay 870

# How many chef-client retries to attempt before failing.
# See Chefctl::Plugin.rerun_chef?
# max_retries 1

# The testing timestamp.
# See https://github.com/facebook/taste-tester
# testing_timestamp '/etc/chef/test_timestamp'

# Whether or not to run chef in whyrun mode.
# whyrun false

# The default location of the chefctl plugin file.
# plugin_path '/etc/chef/chefctl_hooks.rb'

# The default PATH environment variable to use for chef-client.
# path %w{
#  /usr/sbin
#  /usr/bin
# }

# Whether or not to symlink output files for chef.cur.out and chef.last.out
# symlink_output true
