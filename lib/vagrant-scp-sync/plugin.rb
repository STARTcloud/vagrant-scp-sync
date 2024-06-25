# frozen_string_literal: true

module VagrantPlugins
  module ScpSync
    # This defines the class for the plugin vagrant-scp-sync
    class Plugin < Vagrant.plugin('2')
      name 'vagrant-scp-sync'
      description <<-DESC
        Copy files to vagrant boxes via scp
      DESC

      command 'scp' do
        require_relative 'commands/scp'
        Command::ScpSync
      end
    end
  end
end
