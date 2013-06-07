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

      option :tags,
        :short => "-t TAG1,TAG2",
        :long => "--tags TAG1,TAG2",
        :description => "List of tags to output"

      def run

        validate!

        image_list = [
          ui.color('ID', :bold),
          ui.color('Arch', :bold),
          ui.color('Description', :bold),
          ui.color('Root Dev', :bold),
          
          if config[:tags]
            config[:tags].split(",").collect do |tag_name|
              ui.color("Tag:#{tag_name}", :bold)
            end
          end,

          ui.color('Name', :bold)
        ].flatten.compact

        output_column_count = image_list.length

        connection.images.all('is-public' => 'false').sort_by(&:id).each do |image|
          image_list << image.id.to_s
          image_list << image.architecture.to_s
          image_list << image.description.to_s
          image_list << image.root_device_type.to_s
          
          if config[:tags]
            config[:tags].split(",").each do |tag_name|
              image_list << image.tags[tag_name].to_s
            end
          end
          
          image_list << image.name.to_s
        end

        puts ui.list(image_list, :uneven_columns_across, output_column_count)
      end
    end
  end
end
