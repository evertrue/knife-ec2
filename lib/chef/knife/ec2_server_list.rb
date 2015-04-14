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

      banner 'knife ec2 server list (options)'

      option :name,
             short: '-n',
             long: '--no-name',
             boolean: true,
             default: true,
             description: 'Do not display name tag in output'

      option :name_only,
             short: '-o',
             long: '--name-only',
             boolean: true,
             default: false,
             description: 'Only show the name (and nothing else)'

      option :az,
             short: '-z',
             long: '--availability-zone',
             boolean: true,
             default: false,
             description: 'Show availability zones'

      option :vpc,
             short: '-v',
             long: '--vpc',
             boolean: true,
             default: false,
             description: 'Show VPC ID'

      option :key,
             long: '--no-key',
             boolean: true,
             default: true,
             description: 'Disable displaying SSH key'

      option :image,
             long: '--no-image',
             boolean: true,
             default: true,
             description: 'Disable displaying AMI'

      option :tags,
             short: '-t TAG1,TAG2',
             long: '--tags TAG1,TAG2',
             description: 'List of tags to output'

      def fcolor(flavor)
        case flavor
        when 't1.micro'
          :blue
        when 'm1.small'
          :magenta
        when 'm1.medium'
          :cyan
        when 'm1.large'
          :green
        when 'm1.xlarge'
          :red
        else
          :black
        end
      end

      def azcolor(az)
        case az
        when /a$/
          :blue
        when /b$/
          :green
        when /c$/
          :red
        when /d$/
          :magenta
        else
          :cyan
        end
      end

      def groups_with_ids(groups)
        groups.map do|g|
          "#{g} (#{group_id_hash[g]})"
        end
      end

      def vpcs
        @vpcs ||= connection.vpcs.all
      end

      def vpc_with_name(vpc_id)
        this_vpc = vpcs.find { |v| v.id == vpc_id }
        return vpc_id unless !this_vpc.nil? && this_vpc.tags['Name']
        "#{this_vpc.tags['Name']} (#{vpc_id})"
      end

      def all_servers
        @all_servers ||= connection.servers.all
      end

      def header
        o = [ui.color('Instance ID', :bold)]
        o << ui.color('Name', :bold) if config[:name]
        o += [
          ui.color('Public IP', :bold),
          ui.color('Private IP', :bold),
          ui.color('Flavor', :bold)
        ]
        o << ui.color('AZ', :bold) if config[:az]
        o << ui.color('Image', :bold) if config[:image]
        o << ui.color('SSH Key', :bold) if config[:key]

        if config[:tags]
          o += config[:tags].split(',').map do |tag_name|
            ui.color("Tag:#{tag_name}", :bold)
          end
        end

        o << ui.color('Security Groups', :bold)
        o << ui.color('VPC', :bold) if config[:vpc]
        o += [
          ui.color('IAM Profile', :bold),
          ui.color('State', :bold)
        ]
        o
      end

      def servers
        return all_servers.sort_by { |s| s.tags['Name'] || s.id } if
          @name_args.empty?
        o = @name_args.map do |n_a|
          all_servers.select { |s| s.tags['Name'] =~ /#{n_a}/ }
        end
        o.flatten.sort_by { |s| s.tags['Name'] }
      end

      def network_interfaces
        @network_interfaces ||= connection.network_interfaces
      end

      def server_row(server)
        o = [server.id.to_s]
        o << server.tags['Name'].to_s if config[:name]
        o << server.public_ip_address.to_s

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

          o << "#{first_subnet['subnetId']}/#{private_ip}"
        else
          o << server.private_ip_address.to_s
        end

        o << ui.color(server.flavor_id.to_s,
                      fcolor(server.flavor_id.to_s))
        o << ui.color(server.availability_zone.to_s,
                      azcolor(server.availability_zone.to_s)) if config[:az]
        o << server.image_id.to_s if config[:image]
        o << server.key_name.to_s if config[:key]

        if config[:tags]
          o += config[:tags].split(',').map do |tag_name|
            server.tags[tag_name].to_s
          end
        end

        if server.vpc_id
          o << groups_with_ids(server.security_group_ids).join(', ')
        else
          o << server.groups.join(', ')
        end

        o << server.vpc_id ? vpc_with_name(server.vpc_id.to_s) : '-' if config[:vpc]
        o << iam_name_from_profile(server.iam_instance_profile)

        o << begin
          state = server.state.to_s.downcase
          case state
          when 'shutting-down', 'terminated', 'stopping', 'stopped'
            ui.color(state, :red)
          when 'pending'
            ui.color(state, :yellow)
          else
            ui.color(state, :green)
          end
        end
        o
      end

      def group_id_hash
        @group_id_hash ||= Hash[connection.security_groups.map do |g|
          [g.group_id, g.name]
        end]
      end

      def run
        $stdout.sync = true

        validate!

        server_list = config[:name_only] ? [] : header
        output_column_count = config[:name_only] ? 1 : server_list.length

        ui.warn 'No region was specified in knife.rb or as an argument. The ' \
          'default region, us-east-1, will be used:' unless config[:region]

        server_list += servers.map do |server|
          if config[:name_only]
            server.tags['Name'] ? server.tags['Name'] : server.id
          else
            server_row(server)
          end
        end.flatten

        puts ui.list(server_list, :uneven_columns_across, output_column_count)
      end
    end
  end
end
