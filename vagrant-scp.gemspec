# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8

require File.expand_path('lib/vagrant-scp-sync/version', __dir__)

Gem::Specification.new do |spec|
  spec.name          = 'vagrant-scp-sync'
  spec.version       = Vagrant::ScpSync::VERSION
  spec.authors       = ['Mark Gilbert']
  spec.email         = ['Mark.Gilbert@prominic.net']
  spec.summary       = 'Copy files to a Vagrant VM via SCP.'
  spec.description   = spec.summary
  spec.homepage      = 'https://github.com/STARTCloud/vagrant-scp-sync'
  spec.license       = 'AGPL-3.0'
  spec.metadata = {
    'rubygems_mfa_required' => 'true',
    'bug_tracker_uri' => 'https://github.com/STARTcloud/vagrant-scp-sync/issues',
    'changelog_uri' => 'https://github.com/STARTcloud/vagrant-scp-sync/blob/main/CHANGELOG.md',
    'documentation_uri' => 'http://rubydoc.info/gems/vagrant-scp-sync',
    'source_code_uri' => 'https://github.com/STARTCloud/vagrant-scp-sync',
    'github_repo' => 'https://github.com/STARTCloud/vagrant-scp-sync'
  }

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.7.0'
  spec.required_rubygems_version = '>= 1.3.6'
  spec.add_runtime_dependency 'i18n', '~> 1.0'
  spec.add_runtime_dependency 'iniparse', '~> 1.0'
  spec.add_runtime_dependency 'log4r', '~> 1.1'
  spec.add_runtime_dependency 'netaddr', '~> 2.0', '>= 2.0.4'
  spec.add_runtime_dependency 'net-scp', '>= 1.1'
  spec.add_runtime_dependency 'ruby_expect', '~> 1.7', '>= 1.7.5'
end
