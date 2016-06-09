# encoding: utf-8
#
# Copyright 2016, Patrick Muench
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
# author: Christoph Hartmann
# author: Dominik Richter
# author: Patrick Muench

title 'Apache server config'

only_if do
  command(apache.service).exist?
end

title 'Apache server config'

control 'apache-01' do
  impact 1.0
  title 'Apache should be running'
  desc 'Apache should be running.'
  describe service(apache.service) do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end
end

control 'apache-02' do
  title 'Apache should start max. 1 root-task'
  desc 'The Apache service in its own non-privileged account. If the web server process runs with administrative privileges, an attack who obtains control over the apache process may control the entire system.'
  total_tasks = command("ps aux | grep #{apache.service} | grep -v grep | grep root | wc -l | tr -d [:space:]").stdout.to_i
  describe total_tasks do
    it { should eq 1 }
  end
end


control 'apache-03' do
  impact 1.0
  title 'Check Apache config folder owner, group and permissions.'
  desc 'The Apache config folder should owned and grouped by root, be writable, readable and executable by owner. It should be readable, executable by group and not readable, not writeable by others.'
  describe file(apache.conf_dir) do
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
    it { should be_readable.by('owner') }
    it { should be_writable.by('owner') }
    it { should be_executable.by('owner') }
    it { should be_readable.by('group') }
    it { should_not be_writable.by('group') }
    it { should be_executable.by('group') }
    it { should_not be_readable.by('others') }
    it { should_not be_writable.by('others') }
    it { should be_executable.by('others') }
  end
end

control 'apache-04' do
  impact 1.0
  title 'Check Apache config file owner, group and permissions.'
  desc 'The Apache config file should owned and grouped by root, only be writable and readable by owner and not write- and readable by others.'
  describe file(apache.conf_path) do
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
    it { should be_readable.by('owner') }
    it { should be_writable.by('owner') }
    it { should_not be_executable.by('owner') }
    it { should be_readable.by('group') }
    it { should_not be_writable.by('group') }
    it { should_not be_executable.by('group') }
    it { should_not be_readable.by('others') }
    it { should_not be_writable.by('others') }
    it { should_not be_executable.by('others') }
  end
  describe file(File.join(apache.conf_dir,'/conf-enabled/hardening.conf')) do
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
    it { should be_readable.by('owner') }
    it { should be_writable.by('owner') }
    it { should_not be_executable.by('owner') }
    it { should be_readable.by('group') }
    it { should_not be_writable.by('group') }
    it { should_not be_executable.by('group') }
    it { should_not be_readable.by('others') }
    it { should_not be_writable.by('others') }
    it { should_not be_executable.by('others') }
  end
end

control 'apache-05' do
  impact 1.0
  title 'User and group should be set properly'
  desc 'For security reasons it is recommended to run Apache in its own non-privileged account.'
  describe apache_conf do
    its('content') { should match(/^\s*?User\s+?#{apache.user}/) }
    its('content') { should match(/^\s*?Group\s+?#{apache.user}/) }
  end
end

control 'apache-06' do
  impact 1.0
  title 'Set the apache server token'
  desc '\'ServerTokens Prod\' tells Apache to return only Apache as product in the server response header on the every page request'
  describe apache_conf do
    its('content') { should match(/^\s*ServerTokens Prod/) }
  end
end

control 'apache-07' do
  impact 1.0
  title 'Should not load certain modules'
  desc 'Apache HTTP should not load legacy modules'
  describe apache_conf do
    its(:content) { should_not match(/^\s*?LoadModule\s+?dav_module/) }
    its(:content) { should_not match(/^\s*?LoadModule\s+?cgid_module/) }
    its(:content) { should_not match(/^\s*?LoadModule\s+?cgi_module/) }
    its(:content) { should_not match(/^\s*?LoadModule\s+?include_module/) }
  end
end
