# frozen_string_literal: true

require "ruby_llm/providers/test"

module RubyLLM
  # == Testing with RubyLLM::Tester
  #
  # For tests, require +ruby_llm/tester+ to switch to an in-memory provider.
  # It behaves like +Mail::TestMailer+ by collecting prompt interactions in an array:
  #
  #   require "ruby_llm/tester"
  #
  #   RubyLLM::Tester.interactions.clear
  #
  #   RubyLLM.chat.say "Hello!"
  #
  #   RubyLLM::Tester.interactions.size         # => 1
  #   RubyLLM::Tester.interactions.last.role    # => :user
  #   RubyLLM::Tester.interactions.last.content # => "Hello!"
  #
  # The test provider uses an +echo+ protocol and returns the prompt content as
  # the assistant response, so assertions stay deterministic and offline.
  module Tester
    mattr_reader :interactions, default: []

    def self.register *messages
      interactions.concat messages.flatten
    end
  end

  Protocols::Echo.prepend Module.new {
    def complete(messages, ...)
      Tester.register messages

      super
    end
  }

  Provider.register :test, Providers::Test

  configure do |config|
    config.model_registry_file = "test/models.json"
  end
end
