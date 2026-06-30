# frozen_string_literal: true

require "ruby_llm"
require "ruby_llm/protocols/echo"

module RubyLLM
  module Providers
    # In-memory provider intended for tests.
    #
    # This provider mirrors the behavior of a local fake adapter:
    # - it does not initialize any remote connections,
    # - it returns deterministic responses through `echo` protocol.
    class Test < Provider
      protocol :echo, Protocols::Echo

      def self.local? = true

      def initialize(config)
        @config = config
        # skip any connections
      end
    end
  end
end
