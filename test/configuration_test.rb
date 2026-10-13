# frozen_string_literal: true

require "abstract_unit"
require "ruby_llm/tester"
require "agents/base_agent"
require "agents/configured_agent"

class ConfigurationTest < ActiveSupport::TestCase
  test "every agent has its own RubyLLM::Agent class" do
    assert_kind_of  Class, BaseAgent.agent_class
    assert_operator BaseAgent.agent_class, :<, RubyLLM::Agent
    assert_same     BaseAgent.agent_class, BaseAgent.agent_class
    assert_not_same BaseAgent.agent_class, ConfiguredAgent.agent_class
  end

  test "chat uses RubyLLM agent configuration" do
    response = ConfiguredAgent
      .welcome

    assert_equal <<~TEXT.strip, response.content
      You are polite.

      Welcome
    TEXT
  end

  test "params are forwarded to the RubyLLM agent as runtime inputs" do
    response = NamedAgent
      .with(name: "Ava")
      .welcome

    assert_equal <<~TEXT.strip, response.content
      You are Ava.

      Welcome
    TEXT
  end

  test "RubyLLM agent configuration is inherited" do
    response = InheritedConfiguredAgent
      .welcome

    assert_equal <<~TEXT.strip, response.content
      You are polite.

      Welcome
    TEXT

    assert_operator InheritedConfiguredAgent.agent_class, :<, ConfiguredAgent.agent_class
  end
end
