# frozen_string_literal: true

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
  command(apache.service).exist? || file(apache.conf_dir).exist? || service(apache.service).installed?
end

title 'Apache server config'

control 'apache-01' do
  impact 1.0
  title 'Apache should be running'
  desc 'Apache should be running.'
  describe service(apache.service) do
    it { should be_installed }
    it { should be_running }
  end
end

control 'apache-02' do
  impact 1.0
  title 'Apache should be enabled'
  desc 'Configure apache service to be automatically started at boot time'
  only_if { os[:family] != 'ubuntu' && os[:release] != '16.04' } || only_if { os[:family] != 'debian' && os[:release] != '8' }
  describe service(apache.service) do
    it { should be_enabled }
  end
end

control 'apache-03' do
  title 'Apache should start max. 1 root-task'
  desc 'The Apache service in its own non-privileged account. If the web server process runs with administrative privileges, an attack who obtains control over the apache process may control the entire system.'
  total_tasks = command("ps aux | grep #{apache.service} | grep -v grep | grep root | wc -l | tr -d [:space:]").stdout.to_i
  describe total_tasks do
    it { should eq 1 }
  end
end

control 'apache-04' do
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

control 'apache-05' do
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
  describe file(File.join(apache.conf_dir, '/conf-enabled/hardening.conf')) do
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

control 'apache-06' do
  impact 1.0
  title 'User and group should be set properly'
  desc 'For security reasons it is recommended to run Apache in its own non-privileged account.'
  describe apache_conf do
    its('User') { should eq [apache.user] }
    its('Group') { should eq [apache.user] }
  end
end

control 'apache-07' do
  impact 1.0
  title 'Set the apache server token'
  desc '\'ServerTokens Prod\' tells Apache to return only Apache as product in the server response header on the every page request'

  describe file(File.join(apache.conf_dir, '/conf-enabled/security.conf')) do
    its('content') { should match(/^ServerTokens Prod/) }
  end

  # open bug https://github.com/chef/inspec/issues/786, if the bug solved use this test
  # describe apache_conf do
  #   its('ServerTokens') { should eq 'Prod' }
  # end
end

control 'apache-08' do
  impact 1.0
  title 'Should not load certain modules'
  desc 'Apache HTTP should not load legacy modules'

  module_path = File.join(apache.conf_dir, '/mods-enabled/')
  loaded_modules = command('ls ' << module_path).stdout.split.keep_if { |file_name| /.load/.match(file_name) }

  loaded_modules.each do |id|
    describe file(File.join(module_path, id)) do
      its('content') { should_not match(/^\s*?LoadModule\s+?dav_module/) }
      its('content') { should_not match(/^\s*?LoadModule\s+?cgid_module/) }
      its('content') { should_not match(/^\s*?LoadModule\s+?cgi_module/) }
      its('content') { should_not match(/^\s*?LoadModule\s+?include_module/) }
    end
  end

  # open bug https://github.com/chef/inspec/issues/786, if the bug solved use this test
  # describe apache_conf do
  #   its('LoadModule') { should_not eq 'dav_module' }
  #   its('LoadModule') { should_not eq 'cgid_module' }
  #   its('LoadModule') { should_not eq 'cgi_module' }
  #   its('LoadModule') { should_not eq 'include_module' }
  #   its('content') { should_not match(/^\s*?LoadModule\s+?dav_module/) }
  #   its('content') { should_not match(/^\s*?LoadModule\s+?cgid_module/) }
  #   its('content') { should_not match(/^\s*?LoadModule\s+?cgi_module/) }
  #   its('content') { should_not match(/^\s*?LoadModule\s+?include_module/) }
  # end
end

control 'apache-09' do
  impact 1.0
  title 'Disable TRACE-methods'
  desc 'The web server doesn\'t allow TRACE request and help in blocking Cross Site Tracing attack.'

  describe file(File.join(apache.conf_dir, '/conf-enabled/security.conf')) do
    its('content') { should match(/^\s*?TraceEnable\s+?Off/) }
  end

  # open bug https://github.com/chef/inspec/issues/786, if the bug solved use this test
  # describe apache_conf do
  #   its('TraceEnable') { should eq 'Off' }
  # end
end

control 'apache-10' do
  impact 1.0
  title 'Disable insecure HTTP-methods'
  desc 'Disable insecure HTTP-methods and allow only necessary methods.'

  describe file(File.join(apache.conf_dir, '/conf-enabled/hardening.conf')) do
    its('content') { should match(/^\s*?<LimitExcept\s+?GET\s+?POST>/) }
  end

  # open bug https://github.com/chef/inspec/issues/786, if the bug solved use this test
  # describe apache_conf do
  #   its('LimitExcept') { should eq ['GET','POST'] }
  # end
end

control 'apache-11' do
  impact 1.0
  title 'Disable Apache\'s follows Symbolic Links for directories in alias.conf'
  desc 'Should include -FollowSymLinks or +SymLinksIfOwnerMatch for directories in alias.conf'

  describe file(File.join(apache.conf_dir, '/mods-enabled/alias.conf')) do
    its('content') { should match(/-FollowSymLinks/).or match(/\+SymLinksIfOwnerMatch/) }
  end
end

control 'apache-12' do
  impact 1.0
  title 'Disable Directory Listing for directories in alias.conf'
  desc 'Should include -Indexes for directories in alias.conf'

  describe file(File.join(apache.conf_dir, '/mods-enabled/alias.conf')) do
    its('content') { should match(/-Indexes/) }
  end
end

control 'apache-13' do
  impact 1.0
  title 'SSL honor cipher order'
  desc 'When choosing a cipher during an SSLv3 or TLSv1 handshake, normally the client\'s preference is used. If this directive is enabled, the server\'s preference will be used instead.'

  describe file(File.join(apache.conf_dir, '/mods-enabled/ssl.conf')) do
    its('content') { should match(/^\s*?SSLHonorCipherOrder\s+?On/i) }
  end

  sites_enabled_path = File.join(apache.conf_dir, '/sites-enabled/')
  loaded_sites = command('ls ' << sites_enabled_path).stdout.split.keep_if { |file_name| /.conf/.match(file_name) }

  loaded_sites.each do |id|
    virtual_host = file(File.join(sites_enabled_path, id)).content.gsub(/#.*$/, '').scan(%r{<virtualhost.*443(.*?)<\/virtualhost>}im).flatten
    next if virtual_host.empty?

    describe virtual_host do
      it { should include(/^\s*?SSLHonorCipherOrder\s+?On/i) }
    end
  end
end

control 'apache-14' do
  impact 1.0
  title 'Enable Apache Logging'
  desc 'Apache allows you to logging independently of your OS logging. It is wise to enable Apache logging, because it provides more information, such as the commands entered by users that have interacted with your Web server.'

  sites_enabled_path = File.join(apache.conf_dir, '/sites-enabled/')
  loaded_sites = command('ls ' << sites_enabled_path).stdout.split.keep_if { |file_name| /.conf/.match(file_name) }

  loaded_sites.each do |id|
    describe file(File.join(sites_enabled_path, id)).content.gsub(/#.*$/, '').scan(%r{<virtualhost(.*?)<\/virtualhost>}im).flatten do
      it { should include(/CustomLog.*$/i) }
    end
  end
end
