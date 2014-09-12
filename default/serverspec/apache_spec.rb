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

RSpec.configure do |c|
  c.filter_run_excluding skipOn: backend(Serverspec::Commands::Base).check_os[:family]
end

RSpec::Matchers.define :match_key_value do |key, value|
  match do |actual|
    actual =~ /^\s*?#{key}\s*?=\s*?#{value}/
  end
end

# set OS-dependent filenames and paths
case backend.check_os[:family]
when 'Ubuntu', 'Debian'
  apache_config = '/etc/apache2/apache2.conf'
  service_name = 'apache2'
  task_name = 'apache2'
  user_name = 'www-data'
else
  apache_config = '/etc/httpd/conf/httpd.conf'
  service_name = 'httpd'
  task_name = 'httpd'
  user_name = 'apache'
end

tmp_config = '/tmp/httpd.conf'

describe service("#{service_name}") do
  it { should be_enabled }
  it { should be_running }
end

# temporarily combine config-files and remove spaces
describe 'Combining configfiles' do
  describe command("cat #{apache_config} > #{tmp_config}; for i in `grep Include #{apache_config} | cut -d'\"' -f2`; do cat $i >> #{tmp_config}; done;") do
    it { should return_exit_status 0 }
  end
end

# max servers
ret = backend.run_command("grep ServerLimit #{tmp_config} | tr -d [:alpha:][:space:]")
max_servers = ret[:stdout].chomp.to_i

# only a few instances
describe 'Apache Service' do

  it 'should start max. 1 root-tasks' do
    total_tasks = command("ps aux | grep #{task_name} | grep -v grep | grep root | wc -l | tr -d [:space:]").stdout.to_i
    total_tasks.should eq 1
  end

  it "should start max. #{max_servers} tasks" do
    total_tasks = command("ps aux | grep #{task_name} | grep -v grep | wc -l | tr -d [:space:]").stdout.to_i
    total_tasks.should be <= max_servers
  end

end

describe 'Apache Config' do

  # Req. 3.36-3
  it 'config should not be worldwide read- or writeable' do
    num_files = command('find /etc/httpd/ -perm -o+r -type f -o -perm -o+w -type f | wc -l').stdout.to_i
    num_files.should eq 0
  end

  describe file(tmp_config) do
    its(:content) { should match(/^User\s.*?#{user_name}/) }
    its(:content) { should match(/^Group\s.*?#{user_name}/) }
  end

  # Req. 3.01-2
  describe 'should not listen on all interfaces' do
    describe file(tmp_config) do
      its(:content) { should_not match(/^Listen *.80/) }
      its(:content) { should_not match(/^Listen 80/) }
      its(:content) { should_not match(/^Listen *.443/) }
      its(:content) { should_not match(/^Listen 443/) }
      its(:content) { should_not match(/^NameVirtualHost *:443/) }
      its(:content) { should_not match(/^NameVirtualHost *:80/) }
    end
  end

  describe 'should not load certain modules' do
    describe file(tmp_config) do
      its(:content) { should_not match(/^LoadModule dav_module modules\/mod_dav.so/) }
      its(:content) { should_not match(/^LoadModule cgid_module modules\/mod_cgid.so/) }
      its(:content) { should_not match(/^LoadModule cgi_module modules\/mod_cgi.so/) }
      its(:content) { should_not match(/^LoadModule include_module modules\/mod_include.so/) }
    end
  end

  # Req. 3.36-6
  describe 'should disable insecure HTTP-methods' do
    describe file(tmp_config) do
      its(:content) { should match(/^TraceEnable Off/) }
    end
  end

  command("sed -n \"/<Directory/,/Directory>/p\" /tmp/httpd.conf > /tmp/directories.conf")
  total_tags = command('grep Directory /tmp/directories.conf | wc -l').stdout.to_i

  # Req. 3.36-7, 8
  it 'should include -FollowSymLinks or +SymLinksIfOwnerMatch for directories' do
    total_symlinks = command("egrep '\\-FollowSymLinks|+SymLinksIfOwnerMatch' /tmp/directories.conf | wc -l").stdout.to_i
    total_symlinks.should eq total_tags / 2
  end

  # Req. 3.36-9
  it 'should include -Indexes for directories' do
    total_symlinks = command("grep '\\-Indexes' /tmp/directories.conf | wc -l").stdout.to_i
    total_symlinks.should eq total_tags / 2
  end

end

describe 'Virtualhosts' do

  command("sed -n \"/<VirtualHost/,/VirtualHost>/p\" /tmp/httpd.conf > /tmp/vhosts.conf")
  total_tags = command('grep VirtualHost /tmp/vhosts.conf | wc -l').stdout.to_i

  # Req. 3.36-20
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

    # Req. 3.36-19
    describe file(ssl_config) do
      its(:content) { should match(/SSLHonorCipherOrder.*On/) }
    end

  end

end
