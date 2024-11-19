require "log4r"

require "vagrant/util/subprocess"
require "vagrant/util/which"

require_relative "action/scp_sync"

module VagrantPlugins
  module ScpSync
    class SyncedFolder < Vagrant.plugin("2", :synced_folder)
      include Vagrant::Util

      def initialize(*args)
        super

        @logger = Log4r::Logger.new("vagrant_scp_sync")
      end

      def usable?(machine, raise_error=false)
        scp_path = Which.which("scp")
        return true if scp_path
        return false if !raise_error
        raise Vagrant::Errors::SCPNotFound
      end

      def prepare(machine, folders, opts)
      end

      def enable(machine, folders, opts)
        ssh_info = machine.ssh_info

        if ssh_info[:private_key_path].empty? && ssh_info[:password]
          machine.ui.warn(I18n.t("vagrant.scp_ssh_password"))
        end

        folders.each do |id, folder_opts|
          ScpSyncHelper.scp_single(machine, folder_opts)
        end
      end
    end
  end
end
