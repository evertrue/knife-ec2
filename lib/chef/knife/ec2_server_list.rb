#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2010-2011 Opscode, Inc.
# License:: Apache License, Version 2.0
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

require 'chef/knife/ec2_base'

class Chef
  class Knife
    class Ec2ServerList < Knife

      include Knife::Ec2Base

      banner "knife ec2 server list (options)"

      option :name,
        :short => "-n",
        :long => "--no-name",
        :boolean => true,
        :default => true,
        :description => "Do not display name tag in output"

      option :az,
        :short => "-z",
        :long => "--availability-zone",
        :boolean => true,
        :default => false,
        :description => "Show availability zones"

      option :vpc,
        :short => "-v",
        :long => "--vpc",
        :boolean => true,
        :default => false,
        :description => "Show VPC ID"

      option :key,
        :long => "--no-key",
        :boolean => true,
        :default => true,
        :description => "Disable displaying SSH key"

      option :image,
        :long => "--no-image",
        :boolean => true,
        :default => true,
        :description => "Disable displaying AMI"

      option :tags,
        :short => "-t TAG1,TAG2",
        :long => "--tags TAG1,TAG2",
        :description => "List of tags to output"

      def fcolor(flavor)
        case flavor
        when "t1.micro"
          fcolor = :blue
        when "m1.small"
          fcolor = :magenta
        when "m1.medium"
          fcolor = :cyan
        when "m1.large"
          fcolor = :green
        when "m1.xlarge"
          fcolor = :red
        else
          fcolor = :black
        end
      end

      def azcolor(az)
        case az
        when /a$/
          color = :blue
        when /b$/
          color = :green
        when /c$/
          color = :red
        when /d$/
          color = :magenta
        else
          color = :cyan
        end
      end

      def groups_with_ids(groups)
        groups.map{|g|
          "#{g} (#{@group_id_hash[g]})"
        }
      end

      def vpc_with_name(vpc_id)
        this_vpc = @vpcs.select{|v| v.id == vpc_id }.first
        if this_vpc.tags["Name"]
          vpc_name = this_vpc.tags["Name"]
          "#{vpc_name} (#{vpc_id})"
        else
          vpc_id
        end
      end

      def run
        $stdout.sync = true

        validate!

        @group_id_hash = Hash[connection.security_groups.map{|g|
          [g.group_id, g.name]
        }]

        network_interfaces = connection.network_interfaces

        server_list = [
          ui.color('Instance ID', :bold),

          if config[:name]
            ui.color("Name", :bold)
          end,

          ui.color('Public IP', :bold),
          ui.color('Private IP', :bold),
          ui.color('Flavor', :bold),

          if config[:az]
            ui.color('AZ', :bold)
          end,

          if config[:image]
            ui.color('Image', :bold)
          end,

          if config[:key]
            ui.color('SSH Key', :bold)
          end,

          ui.color('Security Groups', :bold),

          if config[:tags]
            config[:tags].split(",").collect do |tag_name|
              ui.color("Tag:#{tag_name}", :bold)
            end
          end,

          if config[:vpc]
            ui.color('VPC', :bold)
          end,

          ui.color('IAM Profile', :bold),
          
          ui.color('State', :bold)
        ].flatten.compact

        output_column_count = server_list.length

        if config[:vpc]
          @vpcs = connection.vpcs.all
        end
        
        if !config[:region]
          ui.warn "No region was specified in knife.rb or as an argument. The default region, us-east-1, will be used:"
        end
        
        connection.servers.all.each do |server|
          server_list << server.id.to_s

          if config[:name]
            server_list << server.tags["Name"].to_s
          end

          server_list << server.public_ip_address.to_s

          if server.subnet_id

            first_subnet = server.network_interfaces.select do |ni|
              ni['networkInterfaceId']
            end.select do |ni|

              network_interfaces.select do |sni|
                sni.attachment &&
                sni.network_interface_id == ni['networkInterfaceId']
              end.first.attachment['deviceIndex'] == '0'

            end.first

            private_ip = network_interfaces.select do |ni|
              ni.network_interface_id == first_subnet['networkInterfaceId']
            end.first.private_ip_address

            server_list << "#{first_subnet['subnetId']}/#{private_ip}"
          else
            server_list << server.private_ip_address.to_s
          end

          server_list << ui.color(
                                  server.flavor_id.to_s,
                                  fcolor(server.flavor_id.to_s)
                                )

          if config[:az]
            server_list << ui.color(
                                server.availability_zone.to_s,
                                azcolor(server.availability_zone.to_s)
                              )
          end

          if config[:image]
            server_list << server.image_id.to_s
          end

          if config[:key]
            server_list << server.key_name.to_s
          end

          if server.vpc_id
            server_list << groups_with_ids(server.security_group_ids).join(", ")
          else
            server_list << server.groups.join(", ")
          end

          if config[:tags]
            config[:tags].split(",").each do |tag_name|
              server_list << server.tags[tag_name].to_s
            end
          end

          if config[:vpc]
            if server.vpc_id
              server_list << vpc_with_name(server.vpc_id.to_s)
            else
              server_list << "-"
            end
          end

          server_list << iam_name_from_profile(server.iam_instance_profile)
          
          server_list << begin
            state = server.state.to_s.downcase
            case state
            when 'shutting-down','terminated','stopping','stopped'
              ui.color(state, :red)
            when 'pending'
              ui.color(state, :yellow)
            else
              ui.color(state, :green)
            end
          end
        end

        puts ui.list(server_list, :uneven_columns_across, output_column_count)

      end
    end
  end
end
