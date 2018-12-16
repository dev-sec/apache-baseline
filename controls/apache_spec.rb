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

HTTPD_ROOT = command("apachectl -V | grep HTTPD_ROOT | cut -d'=' -f2 | sed 's/\"//g'")
HTTPD_CONFIG_FILE = command("apachectl -V | grep SERVER_CONFIG_FILE | cut -d'=' -f2 | sed 's/\"//g'")
HTTPD_CONFIG_FILE_PATH = File.join(HTTPD_ROOT.stdout.strip, HTTPD_CONFIG_FILE.stdout.strip)
HTTPD_USER = command("ps -ef | egrep '(httpd|apache2)' | grep -v root | head -n1 | awk '{print $1}'")

control 'apache-01' do
  impact 1.0
  title 'Apache should be running'
  desc 'Apache should be installed, running and automatically started at boot time'
  if os.debian?
    describe service('apache2') do
      it { should be_installed }
      it { should be_running }
      it { should be_enabled }
    end
  elsif os.redhat?
    describe service('httpd') do
      it { should be_installed }
      it { should be_running }
      it { should be_enabled }
    end
  end
end

control 'apache-03' do
  title 'Apache should start max. 1 root-task'
  desc 'The Apache service in its own non-privileged account. If the web server process runs with administrative privileges, an attack who obtains control over the apache process may control the entire system.'
  total_tasks = command("ps aux | egrep '(apache2|httpd)' | grep -v grep | grep root | wc -l | tr -d [:space:]").stdout.to_i
  describe total_tasks do
    it { should eq 1 }
  end
end

control 'apache-04' do
  impact 1.0
  title 'Check Apache config folder owner, group and permissions.'
  desc 'The Apache config folder should owned and grouped by root, be writable, readable and executable by owner. It should be readable, executable by group and not readable, not writeable by others.'
  describe file(HTTPD_ROOT.stdout.strip) do
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
    it { should_not be_executable.by('others') }
  end
end

control 'apache-05' do
  impact 1.0
  title 'Check Apache config file owner, group and permissions.'
  desc 'The Apache config file should owned and grouped by root, only be writable and readable by owner and not write- and readable by others.'
  describe file(HTTPD_CONFIG_FILE_PATH) do
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
    its('User') { should eq [HTTPD_USER.stdout.strip] }
    its('Group') { should eq [HTTPD_USER.stdout.strip] }
  end
end

control 'apache-07' do
  impact 1.0
  title 'Set the apache server token'
  desc '\'ServerTokens Prod\' tells Apache to return only Apache as product in the server response header on the every page request'
  describe apache_conf do
    its('ServerTokens') { should cmp 'Prod' }
  end
end

control 'apache-08' do
  impact 1.0
  title 'Should not load certain modules'
  desc 'Apache HTTP should not load legacy modules'
  describe command('apachectl -M') do
    its(:stdout) { should_not match(/^\s*?dav_module.*/) }
    its(:stdout) { should_not match(/^\s*?cgid_module.*/) }
    its(:stdout) { should_not match(/^\s*?cgi_module.*/) }
    its(:stdout) { should_not match(/^\s*?include_module.*/) }
  end
end

control 'apache-09' do
  impact 1.0
  title 'Disable TRACE-methods'
  desc 'The web server doesn’t allow TRACE request and help in blocking Cross Site Tracing attack.'
  describe apache_conf do
    its('TraceEnable') { should cmp 'Off' }
  end
end

control 'apache-10' do
  impact 1.0
  title 'Disable insecure HTTP-methods'
  desc 'Disable insecure HTTP-methods and allow only necessary methods.'
  describe apache_conf do
    its('content') { should match(/^\s*?<LimitExcept\s+?GET\s+?POST>/) }
  end
end

control 'apache-11' do
  impact 1.0
  title 'Disable Apaches follows Symbolic Links for directories in alias.conf'
  desc 'Should include -FollowSymLinks or +SymLinksIfOwnerMatch for directories in alias.conf'
  describe apache_conf do
    its('content') { should match(/-FollowSymLinks/).or match(/\+SymLinksIfOwnerMatch/) }
  end
end

control 'apache-12' do
  impact 1.0
  title 'Disable Directory Listing for directories in alias.conf'
  desc 'Should include -Indexes for directories in alias.conf'
  describe apache_conf do
    its('content') { should match(/-Indexes/) }
  end
end

control 'apache-13' do
  impact 1.0
  title 'SSL honor cipher order'
  desc 'When choosing a cipher during an SSLv3 or TLSv1 handshake, normally the client\'s preference is used. If this directive is enabled, the server\'s preference will be used instead.'
  describe apache_conf do
    its('content') { should match(/^\s*?SSLHonorCipherOrder\s+?On/i) }
  end
end

control 'apache-14' do
  impact 1.0
  title 'Enable Apache Logging'
  desc 'Apache allows you to logging independently of your OS logging. It is wise to enable Apache logging, because it provides more information, such as the commands entered by users that have interacted with your Web server.'
  describe apache_conf do
    its('content') { should match(/CustomLog.*$/i) }
  end
end
