# frozen_string_literal: true

require 'vagrant'

module VagrantPlugins
  module ScpSync
    module Errors
      # Namespace for Vagrant SCP Sync Errors
      class VagrantScpSyncError < Vagrant::Errors::VagrantError
        error_namespace('vagrant_scp_sync.errors')
      end

      # Generic error class for all SCP sync errors
      class SyncedFolderScpSyncError < VagrantScpSyncError
        error_key(:scp_sync_error, 'vagrant_scp_sync.errors')
      end

      # This Class denotes that SCP is not installed
      class SCPNotFound < VagrantScpSyncError
        error_key(:scp_installed_error, 'vagrant_scp_sync.errors')
      end
    end
  end
end
