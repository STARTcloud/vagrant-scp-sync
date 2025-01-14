# frozen_string_literal: true

require 'vagrant/util/platform'
require 'vagrant/util/subprocess'
module VagrantPlugins
  module ScpSync
    # Helper class for building SSH options
    class SshOptions
      def self.build(ssh_info)
        opts = %w[
          -o StrictHostKeyChecking=no
          -o UserKnownHostsFile=/dev/null
          -o LogLevel=ERROR
        ]
        opts << "-o port=#{ssh_info[:port]}"
        opts << ssh_info[:private_key_path].map { |k| "-i '#{k}'" }.join(' ')
        opts
      end
    end

    # This will SCP the files
    class ScpSyncHelper
      def self.scp_single(machine, opts, scp_path)
        ssh_info = machine.ssh_info
        raise Vagrant::Errors::SSHNotReady if ssh_info.nil?

        source_files = expand_path(opts[:map], machine)
        target_files = expand_path(opts[:to], machine)

        opts[:owner] ||= ssh_info[:username]
        opts[:group] ||= ssh_info[:username]

        ssh_opts = SshOptions.build(ssh_info)
        scp_opts = build_scp_options(opts)

        delete = scp_opts.include?('--delete')

        # Handle source and target path behaviors
        has_trailing_slash_source = opts[:map].end_with?('/')
        has_trailing_slash_target = opts[:to].end_with?('/')
        is_source_directory = File.directory?(source_files)

        if opts[:direction] == :upload || opts[:direction].nil?
          # For upload direction
          target_check = build_ssh_command(ssh_opts, "test -e '#{target_files}' && echo 'EXISTS' || echo 'NOT_EXISTS'", ssh_info)
          target_type_check = build_ssh_command(ssh_opts, "test -d '#{target_files}' && echo 'DIR' || echo 'FILE'", ssh_info)

          # Check if target exists and its type
          target_exists = execute_command_with_output(machine, target_check).strip == 'EXISTS'
          target_is_dir = target_exists && execute_command_with_output(machine, target_type_check).strip == 'DIR'

          # Determine source path based on trailing slash and directory status
          source = if is_source_directory && has_trailing_slash_source
                     "'#{source_files}'/*"  # Quote path but leave glob outside quotes
                   else
                     "'#{source_files}'"    # Copy directory itself or single file with quotes
                   end

          # Determine target path based on existence and trailing slash
          target_base = "#{ssh_info[:username]}@#{ssh_info[:host]}:'#{target_files}'"
          target = if target_exists && target_is_dir && !has_trailing_slash_target
                     # If target exists as directory but no trailing slash, put source inside it
                     "#{ssh_info[:username]}@#{ssh_info[:host]}:'#{target_files}/#{File.basename(source_files)}'"
                   else
                     target_base
                   end

          # Prepare remote target directory with proper permissions
          target_dir = target_files
          target_dir = File.dirname(target_files) unless target_is_dir || has_trailing_slash_target

          make_dir = build_ssh_command(ssh_opts, "sudo mkdir -p '#{target_dir}'", ssh_info)
          change_ownership = build_ssh_command(ssh_opts, "sudo chown -R #{opts[:owner]}:#{opts[:group]} '#{target_dir}'", ssh_info)
          change_permissions = build_ssh_command(ssh_opts, "sudo chmod -R 777 '#{target_dir}'", ssh_info)
          remove_dir = build_ssh_command(ssh_opts, "sudo rm -rf '#{target_files}'", ssh_info) if delete

        elsif opts[:direction] == :download
          # For download direction
          source = "#{ssh_info[:username]}@#{ssh_info[:host]}:'#{source_files}'"
          source = "#{ssh_info[:username]}@#{ssh_info[:host]}:'#{source_files}'/*" if has_trailing_slash_source

          # Create local target directory without sudo
          target = "'#{target_files}'"
          target_dir = target_files
          target_dir = File.dirname(target_files) unless File.directory?(target_files) || has_trailing_slash_target
          make_dir = "mkdir -p '#{target_dir}'"
        end

        # Execute commands silently for setup
        execute_command(machine, remove_dir, true, nil, opts) if delete
        execute_command(machine, make_dir, true, nil, opts)

        # For upload, ensure remote directory permissions
        if opts[:direction] == :upload || opts[:direction].nil?
          execute_command(machine, change_ownership, true, nil, opts)
          execute_command(machine, change_permissions, true, nil, opts)
        end

        # Build and execute the scp command with sync message
        synchronize = build_scp_command(scp_path, ssh_opts, source, target)
        execute_command(machine, synchronize, true, 'scp_sync_folder', opts)
      end

      def self.expand_path(path, machine)
        expanded_path = File.expand_path(path, machine.env.root_path)
        Vagrant::Util::Platform.fs_real_path(expanded_path).to_s
      end

      def self.build_scp_options(opts)
        opts[:scp__args] ? Array(opts[:scp__args]).dup : ['--verbose']
      end

      def self.build_ssh_command(ssh_opts, command, ssh_info)
        ['ssh', *ssh_opts, "#{ssh_info[:username]}@#{ssh_info[:host]}", "'#{command}'"].join(' ')
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

        raise_scp_error(command, result.stderr) if raise_error && !result.exit_code.zero?
      end

      def self.execute_command_with_output(_machine, command)
        return '' if command.nil?

        result = Vagrant::Util::Subprocess.execute('sh', '-c', command)
        result.stdout
      end

      def self.raise_scp_error(command, stderr)
        raise Errors::SyncedFolderScpSyncError,
              command: command,
              stderr: stderr
      end

      private_class_method :expand_path, :build_scp_options,
                           :build_ssh_command, :build_scp_command, :execute_command,
                           :execute_command_with_output, :raise_scp_error
    end
  end
end
