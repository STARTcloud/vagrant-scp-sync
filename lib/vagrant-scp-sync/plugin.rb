# frozen_string_literal: true

begin
  require 'vagrant'
rescue LoadError
  raise 'The vagrant-scp-sync plugin must be run within Vagrant.'
end

raise 'The vagrant-scp-sync plugin is only compatible with Vagrant 2+' if Vagrant::VERSION < '2'

module VagrantPlugins
  module ScpSync
    # This defines the class for the plugin vagrant-scp-sync
    class Plugin < Vagrant.plugin('2')
      name 'vagrant-scp-sync'
      description <<-DESC
        Copy files to vagrant boxes via scp
      DESC

      command 'scp' do
        setup_i18n
        require_relative 'command'
        Command
      end

      synced_folder('scp', 5) do
        require_relative 'synced_folder'
        SyncedFolder
      end

      def self.setup_i18n
        I18n.load_path << File.expand_path('locales/en.yml', ScpSync.source_root)
        I18n.reload!
      end
    end
  end
end
