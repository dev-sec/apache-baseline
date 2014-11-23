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

describe service("#{service_name}") do
  it { should be_enabled }
  it { should be_running }
end

@max_servers = 0


describe 'Apache Service' do

  it 'should start max. 1 root-tasks' do
    total_tasks = command("ps aux | grep #{task_name} | grep -v grep | grep root | wc -l | tr -d [:space:]").stdout.to_i
    expect(total_tasks).to eq 1
  end

end

describe 'Apache Config' do

  
  it 'config should not be worldwide read- or writeable' do
    num_files = command("find #{apache_config_path} -perm -o+r -type f -o -perm -o+w -type f | wc -l").stdout.to_i
    expect(num_files).to eq 0
  end

  
  describe "should have user and group set to #{user_name}" do
    describe file_with_includes(apache_config, /^\s*Include.*$/) do
      its(:content) { should match(/^\s*?User\s+?#{user_name}/) }
      its(:content) { should match(/^\s*?Group\s+?#{user_name}/) }
    end
  end

  
  describe file_with_includes(apache_config, /^\s*Include.*$/) do
    its(:content) { should match(/^ServerTokens Prod/) }
  end

  describe 'should not load certain modules' do
    describe file_with_includes(apache_config, /^\s*Include.*$/) do
      its(:content) { should_not match(/^\s*?LoadModule\s+?dav_module/) }
      its(:content) { should_not match(/^\s*?LoadModule\s+?cgid_module/) }
      its(:content) { should_not match(/^\s*?LoadModule\s+?cgi_module/) }
      its(:content) { should_not match(/^\s*?LoadModule\s+?include_module/) }
    end
  end

  
  describe 'should disable insecure HTTP-methods' do
    describe file_with_includes(apache_config, /^\s*Include.*$/) do
      its(:content) { should match(/^\s*?TraceEnable\s+?Off/) }
      its(:content) { should match(/^\s*?<LimitExcept\s+?GET\s+?POST>/) }
    end
  end

  describe 'protect directories' do

    # get all the non comment directory tags
    directories = file_with_includes(apache_config, /^\s*Include.*$/).content.gsub(/#.*$/, '').scan(/<directory(.*?)<\/directory>/im).flatten

    
    it 'should include -FollowSymLinks or +SymLinksIfOwnerMatch for directories' do
      expect(directories).to all(match(/-FollowSymLinks/i).or match(/\+SymLinksIfOwnerMatch/i))
    end

    
    it 'should include -Indexes for directories' do
      expect(directories).to all(match(/-Indexes/i))
    end
  end
end

describe 'Virtualhosts' do

  # get all the non comment vhost tags
  vhosts = file_with_includes(apache_config, /^\s*Include.*$/).content.gsub(/#.*$/, '').scan(/<VirtualHost(.*?)<\/VirtualHost>/im).flatten
  
  it 'should include Custom Log' do
    expect(vhosts).to all(match(/CustomLog.*$/i))
  end

  ## get all ssl vhosts
  vhosts = file_with_includes(apache_config, /^\s*Include.*$/).content.gsub(/#.*$/, '').scan(/<VirtualHost.*443(.*?)<\/VirtualHost>/im).flatten

  describe 'SSL Options' do

    
    it 'should include SSLHonorCipherOrder On' do
      expect(vhosts).to all(match(/SSLHonorCipherOrder.*On/i))
    end

  end

end
