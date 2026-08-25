# frozen_string_literal: true

require_relative "lib/action_ai/version"

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "action_ai"
  s.version     = ActionAI::VERSION
  s.summary     = "AI prompt composition and running framework"
  s.description = "AI on Rails. Compose, run, and test AI prompts using the familiar controller/view pattern."

  s.required_ruby_version = ">= 3.4"

  s.license = "MIT"

  s.author   = "Alexander Senko"
  s.email    = "Alexander.Senko@gmail.com"
  s.homepage = "https://github.com/Alexander-Senko/#{s.name}"

  s.files        = Dir["CHANGELOG.md", "README.rdoc", "MIT-LICENSE", "lib/**/*"]
  s.require_path = "lib"
  s.requirements << "none"

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/Alexander-Senko/#{s.name}/issues",
    "changelog_uri"     => "https://github.com/Alexander-Senko/#{s.name}/blob/v#{s.version}/CHANGELOG.md",
    "source_code_uri"   => "https://github.com/Alexander-Senko/#{s.name}/tree/v#{s.version}",
    "rubygems_mfa_required" => "true",
  }

  s.add_dependency "activesupport"
  s.add_dependency "actionpack"
  s.add_dependency "actionview"
  s.add_dependency "activejob"

  s.add_dependency "ruby_llm"
  s.add_dependency "magic-lookup"
  s.add_dependency "memery"
  s.add_dependency "rails-dom-testing", "~> 2.2"
end
