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

# Below is a sample hook file that will rerun chef if chef fails and a
# particular message (in this case, `Try again!`) is found in the chef log.
#
# Hook descriptions and empty hooks have been removed. Refer to the hook
# documentation for descriptions of each method.

module RetryOnLogMessage
  def rerun_chef?(output, chef_exitcode)
    # Don't retry if chef passed
    return false if chef_exitcode == 0

    # Look for `Try again!` in the chef log.
    need_retry = false
    File.foreach(output) do |line|
      if /Try again!/ =~ line
        need_retry = true
        break
      end
    end
    need_retry
  end
end

Chefctl::Plugin.register RetryOnLogMessage
