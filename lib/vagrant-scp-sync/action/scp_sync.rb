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

        original_source_files = opts[:map]
        has_trailing_slash_source_files = original_source_files.end_with?('/')
        source_files = File.expand_path(original_source_files, machine.env.root_path)
        source_files = Vagrant::Util::Platform.fs_real_path(source_files).to_s
        source_files = Vagrant::Util::Platform.cygwin_path(source_files) if Vagrant::Util::Platform.windows?
        sync_source_files = source_files
        sync_source_files += '/*' if has_trailing_slash_source_files
        
        original_target_files = opts[:to]
        has_trailing_slash_target_files = original_target_files.end_with?('/')
        target_files = File.expand_path(original_target_files, machine.env.root_path)
        target_files = Vagrant::Util::Platform.fs_real_path(target_files).to_s
        target_files = Vagrant::Util::Platform.cygwin_path(target_files) if Vagrant::Util::Platform.windows?
        sync_target_files = target_files
        sync_target_files += '/*' if has_trailing_slash_target_files
        
        opts[:owner] ||= ssh_info[:username]
        opts[:group] ||= ssh_info[:username]
        username = ssh_info[:username]
        port = ssh_info[:port]
        host = ssh_info[:host]
        private_key_path = ssh_info[:private_key_path].map { |k| "-i #{k}" }.join(' ')

        args = nil
        args = Array(opts[:scp__args]).dup if opts[:scp__args]
        args ||= ["--verbose"]

        delete = false 
        delete = true if args.include?("--delete")

        if opts[:direction] == :upload || opts[:direction].nil?
          source = sync_source_files
          target = "#{username}@#{host}:#{target_files}"
          make_dir = [
            'ssh',
            '-o StrictHostKeyChecking=no',
            '-o UserKnownHostsFile=/dev/null',
            "-o port=#{port}",
            '-o LogLevel=ERROR',
            private_key_path,
            "#{username}@#{host}",
            "sudo mkdir -p #{target_files}"
          ].join(' ')
          change_ownership = [
            'ssh',
            '-o StrictHostKeyChecking=no',
            '-o UserKnownHostsFile=/dev/null',
            "-o port=#{port}",
            '-o LogLevel=ERROR',
            private_key_path,
            "#{username}@#{host}",
            "sudo chown -R #{opts[:owner]}:#{opts[:group]} #{target_files}"
          ].join(' ')
          change_permissions = [
            'ssh',
            '-o StrictHostKeyChecking=no',
            '-o UserKnownHostsFile=/dev/null',
            "-o port=#{port}",
            '-o LogLevel=ERROR',
            private_key_path,
            "#{username}@#{host}",
            "sudo chmod 777 #{target_files}"
          ].join(' ')
          remove_dir = [
            'ssh',
            '-o StrictHostKeyChecking=no',
            '-o UserKnownHostsFile=/dev/null',
            "-o port=#{port}",
            '-o LogLevel=ERROR',
            private_key_path,
            "#{username}@#{host}",
            "sudo rm -rf #{target_files}"
          ].join(' ')

        elsif opts[:direction] == :download
          source = "#{username}@#{host}:#{sync_source_files}"
          target = target_files
          make_dir = [
            "mkdir -p #{target_files}"
          ].join(' ')
        end

        synchronize = [
          scp_path,
          " -r",
          "-o StrictHostKeyChecking=no",
          "-o UserKnownHostsFile=/dev/null",
          "-o port=#{port}",
          "-o LogLevel=ERROR",
          private_key_path,
          source,
          target
        ].join(' ')

        command = [
          'sh', '-c', remove_dir
        ]

        machine.ui.info(I18n.t('vagrant_scp_sync.action.scp_remove_folder', source_files: source_files, target_files: target_files, command: remove_dir.inspect)) if delete
        rmdir = Vagrant::Util::Subprocess.execute(*command) if delete

        command = [
          'sh', '-c', make_dir
        ]

        machine.ui.info(I18n.t('vagrant_scp_sync.action.scp_make_folder', source_files: source_files, target_files: target_files, command: make_dir.inspect))
        mkdir = Vagrant::Util::Subprocess.execute(*command)

        command = [
          'sh', '-c', change_ownership
        ]

        machine.ui.info(I18n.t('vagrant_scp_sync.action.scp_change_ownership_folder', source_files: source_files, target_files: target_files, command: change_ownership.inspect))
        chown = Vagrant::Util::Subprocess.execute(*command)

        command = [
          'sh', '-c', change_permissions
        ]

        machine.ui.info(I18n.t('vagrant_scp_sync.action.scp_change_permissions_folder', source_files: source_files, target_files: target_files, command: change_permissions.inspect))
        chmod = Vagrant::Util::Subprocess.execute(*command)

        command = [
          'sh', '-c', synchronize
        ]

        machine.ui.info(I18n.t('vagrant_scp_sync.action.scp_sync_folder', source_files: source, target_files: target, command: synchronize.inspect))
        sync = Vagrant::Util::Subprocess.execute(*command)

        if delete
          return if rmdir.exit_code.zero? && mkdir.exit_code.zero? && chmod.exit_code.zero? && chown.exit_code.zero? && sync.exit_code.zero?

          raise Errors::SyncedFolderScpSyncDeleteDirError,
                command: remove_dir.inspect,
                source_files: source_files,
                target_files: target_files,
                stderr: rmdir.stderr unless rmdir.exit_code.zero?
        else
          return if mkdir.exit_code.zero? && chmod.exit_code.zero? && chown.exit_code.zero? && sync.exit_code.zero?
        end
        
        raise Errors::SyncedFolderScpSyncMakeDirError,
              command: make_dir.inspect,
              source_files: source_files,
              target_files: target_files,
              stderr: mkdir.stderr unless mkdir.exit_code.zero?

        raise Errors::SyncedFolderScpSyncChangePermissionsDirError,
              command: change_permissions.inspect,
              source_files: source_files,
              target_files: target_files,
              stderr: chmod.stderr unless chmod.exit_code.zero?

        raise Errors::SyncedFolderScpSyncChangeOwnershipDirError,
              command: change_ownership.inspect,
              source_files: source_files,
              target_files: target_files,
              stderr: chown.stderr unless chown.exit_code.zero?

        raise Errors::SyncedFolderScpSyncError,
              command: synchronize.inspect,
              source_files: source_files,
              target_files: target_files,
              stderr: sync.stderr unless sync.exit_code.zero?

      end
    end
  end
end
