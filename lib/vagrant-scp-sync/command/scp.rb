# frozen_string_literal: true

require 'pathname'
require 'vagrant/util/subprocess'
require 'vagrant/util/which'

module VagrantPlugins
  module ScpSync
    module Command
      # This class defines SCPSync
      class ScpSyncCommand < Vagrant.plugin('2', :command)
        def self.synopsis
          'Copies data into a box via SCP'
        end

        def execute
          @source, @target = parse_args

          with_target_vms(host) do |machine|
            raise Vagrant::Errors::SSHNotReady if machine.ssh_info.nil?

            if @source.nil? && @target.nil?
              # No arguments provided, iterate through all folders
              sync_all_folders(machine)
            else
              # Two arguments provided, sync as before
              sync_files(machine, @source, @target)
            end
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
          return argv if argv && (argv.length == 0 || argv.length == 2)

          @env.ui.info(opts.help, prefix: false)
          [nil, nil]
        end

        require_relative '../action/scp_sync' # Add this line to require the scp_sync file

        def sync_all_folders(machine)
          folders = machine.config.vm.synced_folders
          folders.each_value do |folder_opts|
            scp_path = Vagrant::Util::Which.which('scp')
            VagrantPlugins::ScpSync::ScpSyncHelper.scp_single(machine, folder_opts, scp_path)
          end
        end

        def sync_files(machine, source, target)
          if net_ssh_command(source) == :upload!
            target = "#{machine.ssh_info[:username]}@#{machine.ssh_info[:host]}:'#{format_file_path(target)}'"
            source = "'#{format_file_path(source)}'"
          else
            target = "'#{format_file_path(target)}'"
            source = "#{machine.ssh_info[:username]}@#{machine.ssh_info[:host]}:'#{format_file_path(source)}'"
          end

          proxy_command = if machine.ssh_info[:proxy_command]
                            "-o ProxyCommand='#{machine.ssh_info[:proxy_command]}'"
                          else
                            ''
                          end

          command = [
            'scp',
            '-r',
            '-o StrictHostKeyChecking=no',
            '-o UserKnownHostsFile=/dev/null',
            "-o port=#{machine.ssh_info[:port]}",
            '-o LogLevel=ERROR',
            proxy_command,
            machine.ssh_info[:private_key_path].map { |k| "-i '#{k}'" }.join(' '),
            source,
            target
          ].join(' ')
          log_and_execute(machine, command, 'scp_sync_files', source, target)
        end

        def log_and_execute(machine, command, message_key, source_files, target_files)
          machine.ui.info(
            I18n.t(
              "vagrant_scp_sync.action.#{message_key}",
              command: command,
              source_files: source_files,
              target_files: target_files
            )
          )
          result = `#{command}`
          machine.ui.info(result)
        end

        def host
          host = [@source, @target].map do |file_spec|
            file_spec.match(/^([^:]*):/)[1]
          rescue NoMethodError
            nil
          end.compact.first
          host = nil if host.nil? || host == '' || host.zero?
          host
        end

        def net_ssh_command(source)
          source.include?(':') ? :download! : :upload!
        end

        def format_file_path(filepath)
          if filepath.include?(':')
            filepath.split(':').last.gsub('~', "/home/#{ssh_info[:username]}")
          else
            filepath
          end
        end
      end
    end
  end
end