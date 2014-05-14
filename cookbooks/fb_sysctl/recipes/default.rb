# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
#
# Cookbook Name:: fb_sysctl
# Recipe:: default
#
# Copyright:: Copyright (c) 2014-present, Facebook, Inc.
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

whyrun_safe_ruby_block 'sysctl sanity checks' do
  block do
    node['fb']['fb_sysctl'].to_hash.each do |sysctl, _val|
      if sysctl.start_with?('net.ipv4.ip_conntrack') &&
         !node['kernel']['modules']['nf_conntrack']
        Chef::Log.warn(
          "Trying to set sysctl #{sysctl} without conntrack module!")
        node['fb']['fb_sysctl'].delete(sysctl)
      end
      if sysctl.start_with?('sunrpc') && !node['kernel']['modules']['sunrpc']
        Chef::Log.warn("Trying to set sysctl #{sysctl} without sunrcp module!")
        node['fb']['fb_sysctl'].delete(sysctl)
      end
      if sysctl.start_with?('net.ipv6') && !File.exists?('/proc/sys/net/ipv6')
        Chef::Log.warn("Trying to set #{sysctl}, but IPv6 is turned off!")
        node['fb']['fb_sysctl'].delete(sysctl)
      end
      if sysctl.start_with?('net.bridge') && !node['kernel']['modules']['bridge']
        Chef::Log.warn("Trying to set sysctl #{sysctl} without bridge module!")
        node['fb']['fb_sysctl'].delete(sysctl)
      end
    end
  end
end

template '/etc/sysctl.conf' do
  mode '0644'
  owner 'root'
  group 'root'
  source 'sysctl.conf.erb'
  notifies :run, 'execute[read-sysctl]', :immediately
end

execute 'read-sysctl' do
  command '/sbin/sysctl -p'
  action :nothing
end

# Safety check in case we missed a notification above
execute 'reread-sysctl' do
  not_if { FB::FBSysctl.sysctl_in_sync? }
  command '/sbin/sysctl -p'
end
