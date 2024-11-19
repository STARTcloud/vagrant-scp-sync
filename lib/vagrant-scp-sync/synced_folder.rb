# frozen_string_literal: true

require 'log4r'
require 'vagrant/util/subprocess'
require 'vagrant/util/which'

require_relative 'action/scp_sync'

module VagrantPlugins
  module ScpSync
    # This Class prepares the environment for SCP Sync
    class SyncedFolder < Vagrant.plugin('2', :synced_folder)
      include Vagrant::Util

      def initialize(*args)
        super

        @logger = Log4r::Logger.new('vagrant_scp_sync')
      end

      def usable?(_machine, raise_error=false)
        scp_path = Which.which('scp')
        return true if scp_path

        return false unless raise_error

        raise Vagrant::Errors::SCPNotFound
      end

      def prepare(machine, folders, opts); end

      def enable(machine, folders, _opts)
        ssh_info = machine.ssh_info
        scp_path = Which.which('scp')
        whoami_path = Which.which('whoami')
        machine.ui.warn(I18n.t('vagrant.scp_ssh_password')) if ssh_info[:private_key_path].empty? && ssh_info[:password]
        
        folders.each_value do |folder_opts|
          ScpSyncHelper.scp_single(machine, folder_opts, scp_path, whoami_path)
        end
      end
    end
  end
end
