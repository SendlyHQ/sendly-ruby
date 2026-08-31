# frozen_string_literal: true

require_relative "lib/sendly/version"

Gem::Specification.new do |spec|
  spec.name          = "sendly"
  spec.version       = Sendly::VERSION
  spec.authors       = ["Sendly"]
  spec.email         = ["support@sendly.live"]

  spec.summary       = "Official Ruby SDK for the Sendly SMS API"
  spec.description   = "Send SMS messages globally with the Sendly API. Features include automatic retries, rate limiting, and comprehensive error handling."
  spec.homepage      = "https://github.com/SendlyHQ/sendly-ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/SendlyHQ/sendly-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/SendlyHQ/sendly-ruby/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://sendly.live/docs"

  spec.files = Dir.chdir(__dir__) do
    manifest = %w[
      .ruby-version
      CHANGELOG.md
      Gemfile
      Gemfile.lock
      README.md
      sendly.gemspec
    ]
    (manifest + Dir.glob(["lib/**/*.rb", "examples/**/*.rb"])).select do |f|
      File.file?(f)
    end.sort
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # @deprecated Unused. The client is built on Ruby's standard-library
  #   net/http, which replaces both of these. They stay declared so this minor
  #   release does not drop a runtime dependency that callers may be resolving
  #   transitively; both are slated for removal in the next major version.
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
