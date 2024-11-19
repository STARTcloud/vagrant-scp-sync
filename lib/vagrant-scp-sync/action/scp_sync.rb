require "vagrant/util/platform"
require "vagrant/util/subprocess"

module VagrantPlugins
  module ScpSync
    class ScpSyncHelper
      def self.scp_single(machine, opts)
        ssh_info = machine.ssh_info
        raise Vagrant::Errors::SSHNotReady if ssh_info.nil?

        source_files = opts[:guestpath]
        target_files = opts[:hostpath]
        target_files = File.expand_path(target_files, machine.env.root_path)
        target_files = Vagrant::Util::Platform.fs_real_path(target_files).to_s

        if Vagrant::Util::Platform.windows?
          target_files = Vagrant::Util::Platform.cygwin_path(target_files)
        end

        if !source_files.end_with?("/")
          source_files += "/"
        end

        if !target_files.end_with?("/")
          target_files += "/"
        end

        opts[:owner] ||= ssh_info[:username]
        opts[:group] ||= ssh_info[:username]

        username = ssh_info[:username]
        host = ssh_info[:host]
        proxy_command = if @ssh_info[:proxy_command]
            "-o ProxyCommand='#{@ssh_info[:proxy_command]}' "
          else
            ''
          end

        excludes = ['.vagrant/', 'Vagrantfile']
        excludes += Array(opts[:exclude]).map(&:to_s) if opts[:exclude]
        excludes.uniq!

        args = nil
        args = Array(opts[:args]).dup if opts[:args]
        #args ||= ["--verbose", "--archive", "--delete", "-z", "--copy-links"]

        #if Vagrant::Util::Platform.windows? && !args.any? { |arg| arg.start_with?("--chmod=") }
        #  args << "--chmod=ugo=rwX"

        #  args << "--no-perms" if args.include?("--archive") || args.include?("-a")
        #end

        #args << "--no-owner" unless args.include?("--owner") || args.include?("-o")
        #args << "--no-group" unless args.include?("--group") || args.include?("-g")

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

        machine.ui.info(I18n.t(
          "vagrant.scp_folder", source_files: source_files, target_files: target_files))
        if excludes.length > 1
          machine.ui.info(I18n.t(
            "vagrant.scp_folder_excludes", excludes: excludes.inspect))
        end

        if machine.guest.capability?(:scp_pre)
          machine.guest.capability(:scp_pre, opts)
        end

        command = command + [command_opts]

        r = Vagrant::Util::Subprocess.execute(*command)
        if r.exit_code != 0
          raise Vagrant::Errors::SyncedFolderScpSyncError,
            command: command.inspect,
            source_files: source_files,
            target_files: target_files,
            stderr: r.stderr
        end

        if machine.guest.capability?(:scp_post)
          machine.guest.capability(:scp_post, opts)
        end
      end
    end
  end
end
