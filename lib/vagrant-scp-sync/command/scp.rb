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
              folders = machine.config.vm.synced_folders
              ssh_info = machine.ssh_info
              scp_path = Vagrant::Util::Which.which('scp')
              machine.ui.warn(I18n.t('vagrant.scp_ssh_password')) if ssh_info[:private_key_path].empty? && ssh_info[:password]

              folders.each_value do |folder_opts|
                next unless folder_opts[:type] == :scp

                VagrantPlugins::ScpSync::ScpSyncHelper.scp_single(machine, folder_opts, scp_path)
              end
            else
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
          return argv if argv && (argv.empty? || argv.length == 2)

          @env.ui.info(opts.help, prefix: false)
          [nil, nil]
        end

        require_relative '../action/scp_sync'

        def sync_files(machine, source, target)
          ssh_info = machine.ssh_info

          # Expand the source and target paths
          source = expand_path(source, machine)
          target = expand_path(target, machine)

          # Check if the source ends with a slash and append a wildcard if it does
          source = source.end_with?('/') ? "#{source}*" : source

          if net_ssh_command(source) == :upload!
            target = "#{ssh_info[:username]}@#{ssh_info[:host]}:'#{format_file_path(machine, target)}'"
            source = "'#{format_file_path(machine, source)}'"
          else
            target = "'#{format_file_path(machine, target)}'"
            source = "#{ssh_info[:username]}@#{ssh_info[:host]}:'#{format_file_path(machine, source)}'"
          end

          proxy_command = if machine.ssh_info[:proxy_command]
                            "-o ProxyCommand='#{ssh_info[:proxy_command]}'"
                          else
                            ''
                          end

          command = [
            'scp',
            '-r',
            '-o StrictHostKeyChecking=no',
            '-o UserKnownHostsFile=/dev/null',
            "-o port=#{ssh_info[:port]}",
            '-o LogLevel=ERROR',
            proxy_command,
            machine.ssh_info[:private_key_path].map { |k| "-i '#{k}'" }.join(' '),
            source,
            target
          ].join(' ')
          log_and_execute(machine, command, 'scp_sync_folder', source, target)
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

          result = Vagrant::Util::Subprocess.execute('sh', '-c', command)

          raise VagrantPlugins::ScpSync::Errors::ScpSyncError,
                command: command,
                stderr: result.stderr unless result.exit_code.zero?

          return if result.exit_code.zero?

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

        def expand_path(path, machine)
          expanded_path = File.expand_path(path, machine.env.root_path)
          Vagrant::Util::Platform.fs_real_path(expanded_path).to_s
        end

        def format_file_path(machine, filepath)
          ssh_info = machine.ssh_info
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
