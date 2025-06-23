# frozen_string_literal: true

require "ruby_llm"

module RubyLLM
  module Providers
    # In-memory provider intended for tests.
    #
    # This provider mirrors the behavior of a local fake adapter:
    # - it does not initialize any remote connections,
    # - it returns deterministic responses based on model-specific helpers
    #   (for example, `echo_response` from `Test::Echo`).
    class Test < Provider
      autoload :Echo, "ruby_llm/providers/test/echo"

      include Echo

      def self.local? = true

      def initialize(...)
        # configuration not needed
        # skip any connections
      end

      def complete(messages, model:, **)
        Message.new(
          role:     :assistant,
          model_id: model.id,

          **send("#{model.id}_response", messages)
        ).tap do |message|
          yield message.content if block_given?
        end
      end

      def list_models = [Echo]
          .map(&:info)
    end
  end
end
