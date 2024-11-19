require "vagrant"

module Vagrant
  module Errors
    class SyncedFolderScpSyncError < VagrantError
      error_key(:scp_sync_error, "vagrant_scp_sync.errors")
    end
    class SCPNotFound < VagrantError
      error_key(:scp_installed_error, "vagrant_scp_sync.errors")
    end
  end
end