#
# Author:: Tim Smith <tsmith84@gmail.com>
# Cookbook:: iptables
# Resource:: rule
#
# Copyright:: 2015-2018, Tim Smith
# Copyright:: 2017-2018, Chef Software, Inc.
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

property :source, String
property :cookbook, String
property :variables, Hash, default: {}
property :lines, String
property :table, Symbol

def sync_resources?(src, dst)
  resources_present = src.all? { |rule| dst.include?(rule)}
  if !resources_present
    return true
  end
  false
end

action :enable do
  # ensure we have execute[rebuild-iptables] in the outer run_context
  with_run_context :root do
    find_resource(:execute, 'rebuild-iptables') do
      command '/sbin/rebuild-iptables'
      action :nothing
    end
  end

  rules_persisted = ::File.open(node['iptables']['persisted_rules']).readlines.map(&:chomp)
  if new_resource.lines.nil?
    template "/etc/iptables.d/#{new_resource.name}" do
      source new_resource.source ? new_resource.source : "#{new_resource.name}.erb"
      mode '0644'
      cookbook new_resource.cookbook if new_resource.cookbook
      variables new_resource.variables
      backup false
      notifies :run, 'execute[rebuild-iptables]', :delayed
    end
    # All resources are present in persisted file
    if ::File.exist?("/etc/iptables.d/#{new_resource.name}")
      rules_source = ::File.open("/etc/iptables.d/#{new_resource.name}").readlines.map(&:chomp)
      log 'Sync rules' do
        notifies :run, 'execute[rebuild-iptables]', :delayed
        only_if { sync_resources?(rules_source, rules_persisted) && node['iptables']['sync_rules'] }
      end
    end
  else
    new_resource.lines = "*#{new_resource.table}\n" + new_resource.lines if new_resource.table
    file "/etc/iptables.d/#{new_resource.name}" do
      content new_resource.lines
      mode '0644'
      backup false
      notifies :run, 'execute[rebuild-iptables]', :delayed
    end
    # All resources are present in persisted file
    log 'Sync rules' do
      notifies :run, 'execute[rebuild-iptables]', :delayed
      only_if { sync_resources?(new_resource.lines.split("\n"), rules_persisted) && node['iptables']['sync_rules'] }
    end
  end
end

action :disable do
  # ensure we have execute[rebuild-iptables] in the outer run_context
  with_run_context :root do
    find_resource(:execute, 'rebuild-iptables') do
      command '/usr/sbin/rebuild-iptables'
      action :nothing
    end
  end

  file "/etc/iptables.d/#{new_resource.name}" do
    action :delete
    backup false
    notifies :run, 'execute[rebuild-iptables]', :delayed
  end
end

action :sync do
  persisted_rules = IPTables::Tables.new(::File.readlines(node['iptables']['persisted_rules'])).filter
  active_rules = IPTables::Tables.new(::File.readlines(node['iptables']['saved_rules'])).filter
  active_are_persisted = active_rules.all? { |rule| persisted_rules.include?(rule)}
  persisted_are_active = persisted_rules.all? { |rule| active_rules.include?(rule)}
  log 'Sync rules' do
    notifies :run, 'execute[rebuild-iptables]', :delayed
    only_if { !active_are_persisted || !persisted_are_active }
  end
end
