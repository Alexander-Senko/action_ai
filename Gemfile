# frozen_string_literal: true

source "https://rubygems.org"
gemspec

gem "minitest", "~> 6.0"
gem "minitest-mock"

gem "rake"

gem "railties"

group :rubocop do
	# Rubocop has to be locked in the Gemfile because CI ignores Gemfile.lock
	# We don't want rubocop to start failing whenever rubocop makes a new release.
	gem "rubocop", "< 1.73", require: false
	gem "rubocop-minitest", require: false
	gem "rubocop-packaging", require: false
	gem "rubocop-performance", require: false
	gem "rubocop-rails", require: false
	gem "rubocop-md", require: false

	# This gem is used in Railties tests so it must be a development dependency.
	gem "rubocop-rails-omakase", require: false
end

group :doc do
	gem "sdoc", git: "https://github.com/rails/sdoc.git", branch: "main"
	gem "rdoc", "< 6.10"
	gem "redcarpet", "~> 3.6.1", platforms: :ruby
	gem "w3c_validators", "~> 1.3.6"
	gem "rouge"
	gem "rubyzip", "~> 2.0"
end

# Edge libraries

gem "ruby_llm", github: "crmne/ruby_llm"
