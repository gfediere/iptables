#
# Cookbook:: iptables
# Recipe:: default
#
# Copyright:: 2008-2016, Chef Software, Inc.
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

system_ruby = node['iptables']['system_ruby']

include_recipe 'iptables::_package'

execute 'rebuild-iptables' do
  command '/usr/sbin/rebuild-iptables'
  action :nothing
end

directory '/etc/iptables.d' do
  action :create
end

template '/usr/sbin/rebuild-iptables' do
  source 'rebuild-iptables.erb'
  mode '0755'
  variables(
    hashbang: ::File.exist?(system_ruby) ? system_ruby : '/opt/chef/embedded/bin/ruby',
    persisted_file: node['iptables']['persisted_rules']
  )
end

# iptables service exists only on RHEL based systems
if platform_family?('rhel', 'fedora', 'amazon')
  file '/etc/sysconfig/iptables' do
    content '# Chef managed placeholder to allow iptables service to start'
    action :create_if_missing
  end

  template '/etc/sysconfig/iptables-config' do
    source 'iptables-config.erb'
    mode '600'
    variables config: node['iptables']['iptables_sysconfig']
  end

  template '/etc/sysconfig/ip6tables-config' do
    source 'iptables-config.erb'
    mode '600'
    variables config: node['iptables']['ip6tables_sysconfig']
  end

  service 'iptables' do
    action [:enable, :start]
    supports status: true, start: true, stop: true, restart: true
    not_if { platform_family?('fedora') }
  end
end

if node['iptables']['sync_rules']
  saved_rules = node['iptables']['saved_rules']
  with_run_context :root do
    execute 'iptables-save' do
      command "/sbin/iptables-save > #{saved_rules}"
      action :nothing
    end
  end

  file saved_rules do
    action :create
    notifies :run, 'execute[iptables-save]', :immediately
  end

  iptables_rule 'Synchornize' do
    action :sync
  end
end
