# Copyright 2025-present Facebook
# Copyright 2025-present Phil Dibowitz
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

# Below is a sample hook file that will skip runs when the device is on
# battery.
#
# Hook descriptions and empty hooks have been removed. Refer to the hook
# documentation for descriptions of each method.

module SkipOnBattery
  def skip_run?
    # If a human is requesting the run, they want the run, so don't worry
    # about the battery check.
    #
    # Another option would be to use the cli_options hook to add an
    # override flag, if desired.
    if Chefctl::Config.immediate
      Chefctl.logger.debug('Skipping battery check due to --immediate flag')
      return false
    end

    if File.exist?('/sys/class/power_supply/BAT0/status')
      bat_status = File.read(
        '/sys/class/power_supply/BAT0/status',
      ).strip
      Chefctl.logger.debug("Battery status: #{bat_status}")
      if bat_status == 'Discharging'
        Chefctl.logger.warn('Running on battery power, skipping Chef run')
        return true
      end
    end
    false
  end
end
