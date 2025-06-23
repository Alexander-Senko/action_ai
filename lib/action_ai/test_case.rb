# frozen_string_literal: true

require "active_support/test_case"
require "rails-dom-testing"

module ActionAI
  class NonInferrableAgentError < ::StandardError
    def initialize(name)
      super "Unable to determine the agent to test from #{name}. " \
        "You'll need to specify it using tests YourAgent in your " \
        "test case definition"
    end
  end

  class TestCase < ActiveSupport::TestCase
    module ClearTestInteractions
      extend ActiveSupport::Concern

      included do
        setup :clear_test_interactions
        teardown :clear_test_interactions
      end

      private
        def clear_test_interactions
          if ActionAI.respond_to? :interactions
            ActionAI.interactions.clear
          end
        end
    end

    module Behavior
      extend ActiveSupport::Concern

      include ActiveSupport::Testing::ConstantLookup
      include TestHelper
      include Rails::Dom::Testing::Assertions::SelectorAssertions
      include Rails::Dom::Testing::Assertions::DomAssertions

      included do
        class_attribute :_agent_class
        setup :initialize_test_interactions
        setup :set_expected_message
        ActiveSupport.run_load_hooks(:action_ai_test_case, self)
      end

      module ClassMethods
        def tests(agent)
          case agent
          when String, Symbol
            self._agent_class = agent.to_s.camelize.constantize
          when Module
            self._agent_class = agent
          else
            raise NonInferrableAgentError.new(agent)
          end
        end

        def agent_class
          _agent_class or
            tests determine_default_agent(name)
        end

        def determine_default_agent(name)
          determine_constant_from_test_name(name) do |constant|
            Class === constant && constant < ActionAI::Agent
          end or
            raise NonInferrableAgentError.new(name)
        end
      end

      # Reads the fixture file for the given agent.
      #
      # This is useful when testing agents by being able to write the body of
      # a prompt inside a fixture. See the testing guide for a concrete example:
      # https://guides.rubyonrails.org/testing.html#revenge-of-the-fixtures
      def read_fixture(action)
        IO.readlines(File.join(Rails.root, "test", "fixtures", self.class.agent_class.name.underscore, action))
      end

      private
        def initialize_test_interactions
          ActionAI.interactions.clear
        end

        def set_expected_message
          @expected = RubyLLM::Message.new(
            role: :system,
            content: "",
          )
        end
    end

    include Behavior
  end
end
