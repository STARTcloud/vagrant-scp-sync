# frozen_string_literal: true

begin
  require 'vagrant'
rescue LoadError
  raise 'The vagrant-scp-sync plugin must be run within Vagrant.'
end

if Vagrant::VERSION < '2'
  raise 'The vagrant-scp-sync plugin is only compatible with Vagrant 2+'
end

module VagrantPlugins
  module ScpSync
    # This defines the class for the plugin vagrant-scp-sync
    class Plugin < Vagrant.plugin('2')
      name 'vagrant-scp-sync'
      description <<-DESC
        Copy files to vagrant boxes via scp
      DESC

      command 'scp' do
        setup_logging
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

      def self.setup_logging
        require 'log4r'

        level = nil
        begin
          level = Log4r.const_get(ENV['VAGRANT_LOG'].upcase)
        rescue NameError
          level = nil
        end

        level = nil unless level.is_a?(Integer)

        if level
          logger = Log4r::Logger.new('vagrant_scp_sync')
          logger.outputters = Log4r::Outputter.stderr
          logger.level = level
          logger = nil
        end
      end
    end
  end
end
