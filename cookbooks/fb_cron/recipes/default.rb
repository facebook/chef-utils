#
# Cookbook Name:: fb_cron
# Recipe:: default
#
# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
#
# Copyright:: Copyright (c) 2014-present, Facebook, Inc.
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
#

case node['platform_family']
when 'debian'
  package_name = 'cron'
  svc_name = 'cron'
when 'mac_os_x'
  svc_name = 'com.vix.cron'
when 'rhel'
  package_name = 'vixie-cron'
  if node['platform'] == 'amazon' || node['platform_version'].to_i >= 6
    package_name = 'cronie'
  end
  svc_name = 'crond'
when 'fedora', 'suse'
  package_name 'cronie'
  svc_name = 'crond'
end

if package_name # ~FC023
  package package_name do
    action :upgrade
  end
end

# keep the name 'cron' so we can notify it easily from other places
service 'cron' do
  service_name svc_name
  action [:enable, :start]
end

directory '/etc/cron.d' do
  mode '0755'
  owner 'root'
  group 0 # for Mac. *sigh*
end

# the sa[12] commands here trample on those defined in the
# sysstat_accounting_[12] jobs
file '/etc/cron.d/sysstat' do
  action :delete
end

template '/etc/cron.d/fb_crontab' do
  source 'fb_crontab.erb'
  owner 'root'
  group 'root'
  mode '0644'
end

# Make sure we nuke all old crons from when we used the cron resource
file '/var/spool/cron/root' do
  action :delete
end

# Horrible hack for Mac
cookbook_file '/usr/local/bin/osx_make_crond.sh' do
  only_if { node['platform_family'] == 'mac_os_x' }
  source 'osx_make_crond.sh'
  owner 'root'
  group 0
  mode '0755'
end

execute 'osx_make_crond.sh' do
  only_if { node['platform_family'] == 'mac_os_x' }
  command '/usr/local/bin/osx_make_crond.sh'
end

# in Linux, GNU/Vixie cron can handle the "cron.hourly/daily" folders for
# us. on OS/X, we need to explicitly install and activate anacron to use
# them.
if node['platform_family'] == 'mac_os_x'
  execute 'load_anacron' do
    action :nothing
    command 'port load anacron'
  end

  package 'anacron' do
    action :upgrade
    notifies :run, 'execute[load_anacron]'
  end
end
