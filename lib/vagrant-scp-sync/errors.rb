# frozen_string_literal: true

require 'vagrant'

module VagrantPlugins
  module ScpSync
    module Errors
      # Namespace for Vagrant SCP Sync Errors
      class VagrantScpSyncError < Vagrant::Errors::VagrantError
        error_namespace('vagrant_scp_sync.errors')
      end

      # This Class denotes Errors for SCP Sync
      class SyncedFolderScpSyncError < VagrantScpSyncError
        error_key(:scp_sync_error, 'vagrant_scp_sync.errors')
      end
      
      # This Class denotes Delete Dir Errors for SCP Sync
      class SyncedFolderScpSyncDeleteDirError < VagrantScpSyncError
        error_key(:scp_sync_error_delete_directory, 'vagrant_scp_sync.errors')
      end

      # This Class denotes Make Dir Errors for SCP Sync
      class SyncedFolderScpSyncMakeDirError < VagrantScpSyncError
        error_key(:scp_sync_error_make_directory, 'vagrant_scp_sync.errors')
      end

      # This Class denotes Make Dir Errors for SCP Sync
      class SyncedFolderScpSyncChangePermissionsDirError < VagrantScpSyncError
        error_key(:scp_sync_error_change_permissions_directory, 'vagrant_scp_sync.errors')
      end

      # This Class denotes Make Dir Errors for SCP Sync
      class SyncedFolderScpSyncChangeOwnershipDirError < VagrantScpSyncError
        error_key(:scp_sync_error_change_ownership_directory, 'vagrant_scp_sync.errors')
      end

      # This Class denotes that SCP Sync is not found
      class SCPNotFound < VagrantScpSyncError
        error_key(:scp_installed_error, 'vagrant_scp_sync.errors')
      end
    end
  end
end