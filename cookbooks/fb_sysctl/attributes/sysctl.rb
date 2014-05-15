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

# This is just 'global' settings.
# To add a new one to a tier, just add it in the right cookbook - you don't need
# to touch these unless you want to affect all machines
default['fb']['fb_sysctl'] = {
  # when people want to debug they can turn it on and repro.
  'kernel.core_uses_pid' => 1,
  # rationalise location of cores and naming scheme: procname.pid
  'kernel.core_pattern' => '/var/tmp/cores/%e.%p',

  'kernel.sysrq' => 0,

  'net.ipv4.conf.default.accept_source_route' => 0,
  'net.ipv4.ip_forward' => 0,

  # put more stuff here...
}

# Disable netfilter on bridges by default (https://bugzilla.redhat.com/512206)
if node['kernel']['modules']['bridge']
  {
    'net.bridge.bridge-nf-call-ip6tables' => 0,
    'net.bridge.bridge-nf-call-iptables' => 0,
    'net.bridge.bridge-nf-call-arptables' => 0,
  }.each do |key, val|
    default['fb']['fb_sysctl'][key] = val
  end
end

# Default IPv6 settings
if File.exists?('/proc/sys/net/ipv6')
  {
    'net.ipv6.conf.eth0.accept_ra' => 1,
    'net.ipv6.conf.eth0.autoconf' => 0,
  }.each do |key, val|
    default['fb']['fb_sysctl'][key] = val
  end
end
