# frozen_string_literal: true

require 'vagrant-scp-sync/version'
require 'vagrant-scp-sync/plugin'
require 'vagrant-scp-sync/errors'

module VagrantPlugins
    module ScpSync
      def self.source_root
        @source_root ||= Pathname.new(File.expand_path("../../", __FILE__))
      end
    end
  end