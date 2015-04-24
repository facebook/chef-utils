# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
#
# Copyright:: Copyright (c) 2014-present, Facebook, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module FB
  module FBSysctl
    def self.sysctl_in_sync?(node)
      # Get current settings
      s = Mixlib::ShellOut.new('/sbin/sysctl -a')
      s.run_command
      unless s.exitstatus == 0
        Chef::Log.warn("fb_sysctl: error running /sbin/sysctl -a: #{s.stderr}")
        Chef::Log.debug("STDOUT: #{s.stdout}")
        Chef::Log.debug("STDERR: #{s.stderr}")
        # We couldn't collect current state so cowardly assume all is well
        return true
      end

      current = {}
      s.stdout.split("\n").each do |line|
        line.gsub(/\s+/, ' ').match(/^(\S+) = (.*)$/)
        current[$1] = $2
      end

      # Check desired settings, assume we're in sync unless we find we are not
      insync = true
      node['fb']['fb_sysctl'].to_hash.each do |k, v|
        Chef::Log.debug("fb_sysctl: current #{k} = #{current[k]}")
        desired = v.to_s.gsub(/\s+/, ' ')
        Chef::Log.debug("fb_sysctl: desired #{k} = #{desired}")
        unless desired == current[k]
          insync = false
          Chef::Log.info(
            "fb_sysctl: #{k} current value \"#{current[k]}\" does " +
              "not match desired value \"#{desired}\""
          )
        end
      end
      return insync
    end
  end
end
