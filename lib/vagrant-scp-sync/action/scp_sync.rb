# frozen_string_literal: true

require 'vagrant/util/platform'
require 'vagrant/util/subprocess'

module VagrantPlugins
  module ScpSync
    # This will SCP the files
    class ScpSyncHelper
      def self.scp_single(machine, opts)
        ssh_info = machine.ssh_info
        raise Vagrant::Errors::SSHNotReady if ssh_info.nil?

        source_files = opts[:guestpath]
        target_files = opts[:hostpath]
        target_files = File.expand_path(target_files, machine.env.root_path)
        target_files = Vagrant::Util::Platform.fs_real_path(target_files).to_s
        target_files = Vagrant::Util::Platform.cygwin_path(target_files) if Vagrant::Util::Platform.windows?
        source_files += '/' unless source_files.end_with?('/')
        target_files += '/' unless target_files.end_with?('/')
        opts[:owner] ||= ssh_info[:username]
        opts[:group] ||= ssh_info[:username]
        username = ssh_info[:username]
        host = ssh_info[:host]
        proxy_command = if @ssh_info[:proxy_command]
                          "-o ProxyCommand='#{@ssh_info[:proxy_command]}' "
                        else
                          ''
                        end

        if opts[:direction] == :upload || opts[:direction].nil?
          source = "'#{source_files}'"
          target = "#{username}@#{host}:'#{target_files}'"
        elsif opts[:direction] == :download
          source = "#{username}@#{host}:'#{source_files}'"
          target = "'#{target_files}'"
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

        command_opts = {}
        command_opts[:workdir] = machine.env.root_path.to_s

        machine.ui.info(I18n.t('vagrant.scp_folder', source_files: source_files, target_files: target_files))

        command = command + [command_opts]

        r = Vagrant::Util::Subprocess.execute(*command)
        if r.exit_code != 0
          raise Vagrant::Errors::SyncedFolderScpSyncError,
                command: command.inspect,
                source_files: source_files,
                target_files: target_files,
                stderr: r.stderr
        end
      end
    end
  end
end
