# frozen_string_literal: true

require_relative 'lib/bashvar/version'

Gem::Specification.new do |spec|
  spec.name          = 'bashvar'
  spec.version       = BashVar::VERSION
  spec.authors       = ['Daisuke Fujimura']
  spec.email         = ['booleanlabel@gmail.com']

  spec.summary       = 'Parse Bash declare -p output into Ruby data structures.'
  spec.description   = "A simple, dependency-free Ruby library to parse the output of Bash's `declare -p` command, converting shell variables into corresponding Ruby types like String, Integer, Array, and Hash."
  spec.homepage      = 'https://github.com/fd00/bashvar'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'fasterer', '>= 0.11.0'
  spec.add_development_dependency 'rake', '>= 13.3.0'
  spec.add_development_dependency 'rspec', '>= 3.13.1'
  spec.add_development_dependency 'rubocop', '>= 1.78.0'
  spec.add_development_dependency 'rubocop-performance', '>= 1.25.0'
end
