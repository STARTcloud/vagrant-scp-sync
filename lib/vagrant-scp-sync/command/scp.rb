# frozen_string_literal: true

require 'pathname'
require 'vagrant/util/subprocess'

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
              machine.ui.warn(I18n.t('vagrant.scp_ssh_password')) if ssh_info[:private_key_path].empty? && ssh_info[:password]
              folders.each_value do |folder_opts|
                next unless folder_opts[:type] == :scp

                VagrantPlugins::ScpSync::ScpSyncHelper.scp_single(machine, folder_opts)
              end
            else
              ssh_info = machine.ssh_info
              direction = net_ssh_command(@source)
              source = format_file_path(machine, @source)
              target = format_file_path(machine, @target)
              folder_opts = {
                type: :scp,
                map: source,
                to: target,
                owner: ssh_info[:username],
                group: ssh_info[:username],
                direction: direction,
                scp__args: ['--delete'],
                rsync__args: ['--delete'],
                disabled: false,
                guestpath: target,
                hostpath: source
              }

              VagrantPlugins::ScpSync::ScpSyncHelper.scp_single(machine, folder_opts)
            end
          end
        end

        private

        def parse_args
          opts = OptionParser.new do |o|
            o.banner =  "Usage: vagrant scp|sync <local_path> [vm_name]:<remote_path> \n"
            o.banner += "       vagrant scp|sync [vm_name]:<remote_path> <local_path> \n"
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
          source.include?(':') ? :download : :upload
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
