#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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
#

require 'chef/knife/ec2_base'

class Chef
  class Knife
    class Ec2ImageList < Knife

      include Knife::Ec2Base

      banner "knife ec2 image list (options)"

      def run

        validate!

        flavor_list = [
          ui.color('ID', :bold),
          ui.color('Architecture', :bold),
          ui.color('Description', :bold),
          ui.color('Root Dev', :bold),
          ui.color('Tag:Name', :bold),
          ui.color('Name', :bold)
        ]
        connection.images.all('is-public' => 'false').sort_by(&:id).each do |flavor|
          flavor_list << flavor.id.to_s
          flavor_list << flavor.architecture.to_s
          flavor_list << flavor.description.to_s
          flavor_list << flavor.root_device_type.to_s
          flavor_list << flavor.tags["Name"].to_s
          flavor_list << flavor.name.to_s
        end
        puts ui.list(flavor_list, :columns_across, 6)
      end
    end
  end
end
