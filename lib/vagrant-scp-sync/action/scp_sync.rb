# frozen_string_literal: true

require 'vagrant/util/platform'
require 'vagrant/util/subprocess'

module VagrantPlugins
  module ScpSync
    # This will SCP the files
    class ScpSyncHelper
      def self.scp_single(machine, opts, scp_path)
        ssh_info = machine.ssh_info
        raise Vagrant::Errors::SSHNotReady if ssh_info.nil?

        source_files = expand_path(opts[:map], machine)
        has_trailing_slash_source = opts[:map].end_with?('/')
        sync_source_files = append_wildcard(source_files, has_trailing_slash_source)
        target_files = expand_path(opts[:to], machine)

        opts[:owner] ||= ssh_info[:username]
        opts[:group] ||= ssh_info[:username]

        ssh_opts = build_ssh_options(ssh_info)
        scp_opts = build_scp_options(opts)

        delete = scp_opts.include?('--delete')

        if opts[:direction] == :upload || opts[:direction].nil?
          source = sync_source_files
          target = "#{ssh_info[:username]}@#{ssh_info[:host]}:#{target_files}"
          make_dir = build_ssh_command(ssh_opts, "sudo mkdir -p #{target_files}", ssh_info)
          change_ownership = build_ssh_command(ssh_opts, "sudo chown -R #{opts[:owner]}:#{opts[:group]} #{target_files}", ssh_info)
          change_permissions = build_ssh_command(ssh_opts, "sudo chmod 777 #{target_files}", ssh_info)
          remove_dir = build_ssh_command(ssh_opts, "sudo rm -rf #{target_files}", ssh_info)
        elsif opts[:direction] == :download
          source = "#{ssh_info[:username]}@#{ssh_info[:host]}:#{sync_source_files}"
          target = target_files
          
          # For directory sync or explicit directory target (ends with slash), create the full path
          if has_trailing_slash_source || target.end_with?('/')
            make_dir = "mkdir -p #{target}"
          else
            # For file targets, only create the parent directory if it's not '.'
            parent_dir = File.dirname(target)
            make_dir = parent_dir == '.' ? nil : "mkdir -p #{parent_dir}"
          end
        end

        synchronize = build_scp_command(scp_path, ssh_opts, source, target)
        execute_command(machine, remove_dir, delete, nil, opts)
        execute_command(machine, make_dir, false, nil, opts)
        execute_command(machine, change_ownership, false, nil, opts)
        execute_command(machine, change_permissions, false, nil, opts)
        execute_command(machine, synchronize, true, 'scp_sync_folder', opts)
      end

      def self.expand_path(path, machine)
        expanded_path = File.expand_path(path, machine.env.root_path)
        Vagrant::Util::Platform.fs_real_path(expanded_path).to_s
      end

      def self.append_wildcard(path, has_trailing_slash)
        has_trailing_slash ? "#{path}/*" : path
      end

      def self.build_ssh_options(ssh_info)
        opts = %w[
          -o StrictHostKeyChecking=no
          -o UserKnownHostsFile=/dev/null
          -o LogLevel=ERROR
        ]
        opts << "-o port=#{ssh_info[:port]}"
        opts << ssh_info[:private_key_path].map { |k| "-i #{k}" }.join(' ')
        opts
      end

      def self.build_scp_options(opts)
        opts[:scp__args] ? Array(opts[:scp__args]).dup : ['--verbose']
      end

      def self.build_ssh_command(ssh_opts, command, ssh_info)
        ['ssh', *ssh_opts, "#{ssh_info[:username]}@#{ssh_info[:host]}", command].join(' ')
      end

      def self.build_scp_command(scp_path, ssh_opts, source, target)
        [scp_path, '-r', *ssh_opts, source, target].join(' ')
      end

      def self.execute_command(machine, command, raise_error, message_key, opts)
        return if command.nil?

        if message_key
          machine.ui.info(
            I18n.t(
              "vagrant_scp_sync.action.#{message_key}",
              command: command,
              target_files: opts[:to],
              source_files: opts[:map]
            )
          )
        end

        result = Vagrant::Util::Subprocess.execute('sh', '-c', command)

        raise_scp_error(message_key, command, result.stderr) if raise_error && !result.exit_code.zero?
      end

      def self.raise_scp_error(message_key, command, stderr)
        raise Errors.const_get("SyncedFolderScpSync#{message_key.split('_').map(&:capitalize).join}Error"),
              command: command,
              stderr: stderr
      end

      private_class_method :expand_path, :append_wildcard, :build_ssh_options, :build_scp_options,
                           :build_ssh_command, :build_scp_command, :execute_command, :raise_scp_error
    end
  end
end
