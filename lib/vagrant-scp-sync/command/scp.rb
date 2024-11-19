# frozen_string_literal: true

require 'pathname'

module VagrantPlugins
  module ScpSync
    module Command
      # This class defines SCPSync
      class ScpSync < Vagrant.plugin(2, :command)
        def self.synopsis
          'Copies data into a box via SCP'
        end

        def execute
          @file1, @file2 = parse_args
          return if @file2.nil?

          with_target_vms(host) do |machine|
            @ssh_info = machine.ssh_info
            raise Vagrant::Errors::SSHNotReady if @ssh_info.nil?

            user_at_host = "#{@ssh_info[:username]}@#{@ssh_info[:host]}"
            if net_ssh_command == :upload!
              target = "#{user_at_host}:'#{target_files}'"
              source = "'#{source_files}'"
            else
              target = "'#{target_files}'"
              source = "#{user_at_host}:'#{source_files}'"
            end

            proxy_command = if @ssh_info[:proxy_command]
                              "-o ProxyCommand='#{@ssh_info[:proxy_command]}'"
                            else
                              ''
                            end

            command = [
              'scp',
              '-r',
              '-o StrictHostKeyChecking=no',
              '-o UserKnownHostsFile=/dev/null',
              "-o port=#{@ssh_info[:port]}",
              '-o LogLevel=ERROR',
              proxy_command,
              @ssh_info[:private_key_path].map { |k| "-i '#{k}'" }.join(' '),
              source,
              target
            ].join(' ')
            system(command)
          end
        end

        private

        def parse_args
          opts = OptionParser.new do |o|
            o.banner =  "Usage: vagrant scp <local_path> [vm_name]:<remote_path> \n"
            o.banner += "       vagrant scp [vm_name]:<remote_path> <local_path> \n"
            o.banner += 'Directories will be copied recursively.'
            o.separator ''
            o.separator 'Options:'
            o.separator ''
          end
          argv = parse_options(opts)
          return argv if argv && argv.length == 2

          @env.ui.info(opts.help, prefix: false) if argv
          [nil, nil]
        end

        def host
          host = [@file1, @file2].map do |file_spec|
            file_spec.match(/^([^:]*):/)[1]
          rescue NoMethodError
            nil
          end.compact.first
          host = nil if host.nil? || host == '' || host.zero?
          host
        end

        def net_ssh_command
          @file1.include?(':') ? :download! : :upload!
        end

        def source_files
          format_file_path(@file1)
        end

        def target_files
          if target_location_specified?
            format_file_path(@file2)
          else
            Pathname.new(source_files).basename
          end
        end

        def format_file_path(filepath)
          if filepath.include?(':')
            filepath.split(':').last.gsub('~', "/home/#{@ssh_info[:username]}")
          else
            filepath
          end
        end

        def target_location_specified?
          !@file2.end_with?(':')
        end
      end
    end
  end
end
