# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
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

# These jobs should run on EVERY machine in the fleet. Be selective.
jobs = {}

if node['os'] == 'linux'
  case node['platform_family']
  when 'rhel', 'fedora', 'suse'
    sa_dir = '/usr/lib64/sa'
  when 'debian'
    sa_dir = '/usr/lib/sysstat'
  end

  {
    'sysstat_accounting_1' => {
      'time' => '* * * * *',
      'command' => "#{sa_dir}/sa1 -S DISK,SNMP 1 1 &> /dev/null"
    },
    'sysstat_accounting_2' => {
      'time' => '* * * * *',
      'command' => "#{sa_dir}/sa2 -A &> /dev/null"
    },
  }.each do |k, v|
    jobs[k] = v
  end
end

default['fb']['fb_cron'] = {
  'jobs' = jobs
}
