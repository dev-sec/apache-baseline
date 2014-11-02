# encoding: utf-8
#
# Copyright 2014, Deutsche Telekom AG
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

require 'spec_helper'

RSpec::Matchers.define :match_key_value do |key, value|
  match do |actual|
    actual =~ /^\s*?#{key}\s*?=\s*?#{value}/
  end
end

# set OS-dependent filenames and paths
case os[:family]
when 'ubuntu', 'debian'
  apache_config_path = '/etc/apache2/'
  apache_config = File.join(apache_config_path, 'apache2.conf')
  service_name = 'apache2'
  task_name = 'apache2'
  user_name = 'www-data'
else
  apache_config_path = '/etc/httpd/'
  apache_config = File.join(apache_config_path, '/conf/httpd.conf')
  service_name = 'httpd'
  task_name = 'httpd'
  user_name = 'apache'
end

tmp_config = '/tmp/httpd.conf'

describe service("#{service_name}") do
  it { should be_enabled }
  it { should be_running }
end

@max_servers = 0

# temporarily combine config-files and remove spaces
describe 'Combining configfiles' do

  describe command("cat #{apache_config} > #{tmp_config}; for i in `egrep '^\\s*Include' #{apache_config} | awk '{ print $2}'`; do [ $(ls -A $i) ]  && cat $i >> #{tmp_config} || echo no files in $i ; done;") do
    its(:exit_status) { should eq 0 }
  end

end

# DTAG SEC: Req 3.03-2, Req 3.36-2 (nur eine instanz pro server + ein Process als root laufen lassen)
describe 'Apache Service' do

  it 'should start max. 1 root-tasks' do
    total_tasks = command("ps aux | grep #{task_name} | grep -v grep | grep root | wc -l | tr -d [:space:]").stdout.to_i
    expect(total_tasks).to eq 1
  end

end

describe 'Apache Config' do

  # DTAG SEC: Req 3.36-3
  it 'config should not be worldwide read- or writeable' do
    num_files = command("find #{apache_config_path} -perm -o+r -type f -o -perm -o+w -type f | wc -l").stdout.to_i
    expect(num_files).to eq 0
  end

  # DTAG SEC: Req 3.36-1, Req 3.36-2
  describe "should have user and group set to #{user_name}" do
    describe file(tmp_config) do
      its(:content) { should match(/^\s*?User\s+?#{user_name}/) }
      its(:content) { should match(/^\s*?Group\s+?#{user_name}/) }
    end
  end

  # DTAG SEC: Req 3.36-12
  pending file(tmp_config) do
    its(:content) { should match(/^ServerTokens Prod/) }
  end

  describe 'should not load certain modules' do
    describe file(tmp_config) do
      its(:content) { should_not match(/^\s*?LoadModule \s*?dav_module/) }
      its(:content) { should_not match(/^\s*?LoadModule \s*?cgid_module/) }
      its(:content) { should_not match(/^\s*?LoadModule \s*?cgi_module/) }
      its(:content) { should_not match(/^\s*?LoadModule \s*?include_module/) }
    end
  end

  # DTAG SEC: Req 3.36-6
  describe 'should disable insecure HTTP-methods' do
    describe file(tmp_config) do
      its(:content) { should match(/^\s*?TraceEnable \s*?Off/) }
      its(:content) { should match(/^\s*?<LimitExcept \s*?GET \s*?POST>/) }
    end
  end

  command("sed -n \"/<Directory/,/Directory>/p\" /tmp/httpd.conf > /tmp/directories.conf")
  total_tags = command('grep Directory /tmp/directories.conf | wc -l').stdout.to_i

  # DTAG SEC: Req 3.36-7, 8
  it 'should include -FollowSymLinks or +SymLinksIfOwnerMatch for directories' do
    total_symlinks = command("egrep '\\-FollowSymLinks|+SymLinksIfOwnerMatch' /tmp/directories.conf | wc -l").stdout.to_i
    total_symlinks.should eq total_tags / 2
  end

  # DTAG SEC: Req 3.36-9
  it 'should include -Indexes for directories' do
    total_symlinks = command("grep '\\-Indexes' /tmp/directories.conf | wc -l").stdout.to_i
    total_symlinks.should eq total_tags / 2
  end

end

describe 'Virtualhosts' do

  command("sed -n \"/<VirtualHost/,/VirtualHost>/p\" /tmp/httpd.conf > /tmp/vhosts.conf")
  total_tags = command('grep VirtualHost /tmp/vhosts.conf | wc -l').stdout.to_i

  # DTAG SEC: Req 3.36-20
  it 'should log access' do
    total_logs = command("egrep 'CustomLog.*combined' /tmp/vhosts.conf | wc -l").stdout.to_i
    total_logs.should eq total_tags / 2
  end

end

ssl_on = command("grep \"LoadModule ssl_module modules/mod_ssl.so\" #{tmp_config} | wc -l").stdout.to_i

if ssl_on == 1

  ssl_config = '/tmp/ssl_vhosts.conf'
  command("sed -n \"/<VirtualHost.*443/,/VirtualHost>/p\" /tmp/httpd.conf >  #{ssl_config}")

  describe 'Securehost' do

    # DTAG SEC: Req 3.36-19
    describe file(ssl_config) do
      its(:content) { should match(/SSLHonorCipherOrder.*On/) }
    end

  end

end
