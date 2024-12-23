# frozen_string_literal: true

module VagrantPlugins
  module ScpSync
    # Helper class for building SSH options
    class SshOptions
      def self.build(ssh_info)
        opts = %w[
          -o StrictHostKeyChecking=no
          -o UserKnownHostsFile=/dev/null
          -o LogLevel=ERROR
        ]
        opts << "-o port=#{ssh_info[:port]}"
        opts << ssh_info[:private_key_path].map { |k| "-i #{k}" }.join(' ')
        opts
      end
    end
  end
end
