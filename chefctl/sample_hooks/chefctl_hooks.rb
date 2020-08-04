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

# This hook file is located at '/etc/chef/chefctl_hooks.rb'
# You can change this location by passing `-p/--plugin-path` to `chefctl`,
# or by setting `plugin_path` in `chefctl-config.rb`

# Below is a sample hook module with commented out methods for each hook.
# You can use this as a starting point for writing your own hooks,
# just copy this, change the module name, and uncomment the methods you want
# to use.

module SampleHook
  # Used to initialize the hook
  # def initialize
  # end

  # Called during command line option parsing.
  # Allows a plugin to define additional command-line arguments.
  # Parameters:
  # - parser: an OptionParser object
  # The return value is ignored.
  # def cli_options(parser)
  # end

  # Called between command line parsing, and acquiring the lock.
  # This hook is intended to be used to modify config options via
  # Chefctl::Config, or do other setup items for the hooks.
  # Setup items for the chef run should be placed in pre_run, since
  # pre_start is called before the lock is acquired.
  # The return value is ignored.
  # def pre_start
  # end

  # Gets the hostname of the machine. This sets the HOSTNAME environment
  # variable for the chef-client process.
  # Returns the hostname of the machine as a string.
  # def hostname
  # end

  # Validates the authenticity of chef certificates, regenerating
  # them if necessary.
  # The return value is ignored.
  # def generate_certs
  # end

  # Called after the lock is acquired, before the chef run is started.
  # Parameters:
  # - output is the path to the log file for the chef run
  # The return value is ignored.
  # def pre_run(output)
  # end

  # Called after the final chef run completes, before the lock is released.
  # Normally this would be after the first (and only) chef run, but
  # re-runs can be triggered by the `rerun_chef?` hook, in which case
  # this hook is called exactly once after the final chef run.
  # Parameters:
  # - output is the path to the log file for the chef run.
  # - chef_exitcode is the exit code of the final chef-client process.
  #   (>0 on failure)
  # The return value is ignored.
  # def post_run(output, chef_exitcode)
  # end

  # Check whether or not another chef run is required.
  # Parameters:
  # - output is the path to the log file for the chef run.
  # - chef_exitcode is the chef-client exit code. (>0 on failure)
  # Returns a boolean indicating if another chef run should be performed.
  # This hook is called at most `Chefctl::Config.max_retries` times.
  # With the default value of 1 retry, this hook is not called a second time,
  # regardless of the result of the chef re-run.
  # def rerun_chef?(output, chef_exitcode)
  # end
end

Chefctl::Plugin.register SampleHook
