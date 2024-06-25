# frozen_string_literal: true

begin
  require 'vagrant'
rescue LoadError
  raise 'The vagrant-scp-sync plugin must be run within Vagrant.'
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
        require_relative 'commands/scp.rb'
        Command::ScpSync
      end
    end
  end
end
