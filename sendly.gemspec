# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "sendly"
  spec.version       = "1.5.1"
  spec.authors       = ["Sendly"]
  spec.email         = ["support@sendly.live"]

  spec.summary       = "Official Ruby SDK for the Sendly SMS API"
  spec.description   = "Send SMS messages globally with the Sendly API. Features include automatic retries, rate limiting, and comprehensive error handling."
  spec.homepage      = "https://github.com/sendly-live/sendly-ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/sendly-live/sendly-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/sendly-live/sendly-ruby/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://sendly.live/docs"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
