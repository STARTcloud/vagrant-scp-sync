# frozen_string_literal: true

require 'vagrant'

module Vagrant
  module Errors
    # This Class denotes Errors for SCP Sync
    class SyncedFolderScpSyncError < VagrantError
      error_key(:scp_sync_error, 'vagrant_scp_sync.errors')
    end

    # This Class denotes that SCP Sync is not found
    class SCPNotFound < VagrantError
      error_key(:scp_installed_error, 'vagrant_scp_sync.errors')
    end
  end
end
