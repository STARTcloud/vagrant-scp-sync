# frozen_string_literal: true

require 'pathname'

module VagrantPlugins
  # This is used to SCP files to/from Guests and Hosts
  module ScpSync
    lib_path = Pathname.new(File.expand_path('vagrant-scp-sync', __dir__))
    autoload :Errors, lib_path.join('errors')
    def self.source_root
      @source_root ||= Pathname.new(File.expand_path('..', __dir__))
    end
  end
end

begin
  require 'vagrant'
rescue LoadError
  raise 'The Vagrant vagrant-zones plugin must be run within Vagrant.'
end

raise 'The Vagrant vagrant-zones plugin is only compatible with Vagrant 2+.' if Vagrant::VERSION < '2'

require 'vagrant-scp-sync/version'
require 'vagrant-scp-sync/plugin'
