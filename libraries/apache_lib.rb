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

class Apachelib < Inspec.resource(1)
  name 'apache_lib'

  def valid_taskname
    # define apache task/service name for different distros

    centos_taskname = 'httpd'
    debian_taskname = 'apache2'
    apache_taskname = debian_taskname

    case inspec.os[:family]
    when 'ubuntu', 'debian'
      apache_taskname
    when 'redhat', 'centos'
      apache_taskname = centos_taskname
    end

    apache_taskname
  end

  def valid_users
    # define apache user for different distros

    centos_user = 'apache'
    debian_user = 'www-data'
    web_user = debian_user

    # adjust the nginx user based on OS
    case inspec.os[:family]
    when 'ubuntu', 'debian'
      web_user
    when 'redhat', 'centos'
      web_user = centos_user
    end

    web_user
  end

  def valid_path
    # define apache config path for different distros
    centos_path = '/etc/httpd/'
    debian_path = '/etc/apache2/'
    apache_config_path = debian_path

    # adjust the nginx user based on OS
    case inspec.os[:family]
    when 'ubuntu', 'debian'
      apache_config_path
    when 'redhat', 'centos'
      apache_config_path = centos_path
    end

    apache_config_path
  end

  def valid_config
    # define apache config path for different distros
    centos_config = '/conf/httpd.conf'
    debian_config = 'apache2.conf'
    apache_config = File.join(self.valid_path, debian_config)

    # adjust the nginx user based on OS
    case inspec.os[:family]
    when 'ubuntu', 'debian'
      apache_config = File.join(self.valid_path, debian_config)
    when 'redhat', 'centos'
      apache_config = File.join(self.valid_path, centos_config)
    end

    apache_config
  end
end
