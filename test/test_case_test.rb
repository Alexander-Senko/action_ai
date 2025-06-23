# frozen_string_literal: true

require "abstract_unit"

class TestTestAgent < ActionAI::Agent
end

class ManuallySetNameAgentTest < ActionAI::TestCase
  tests TestTestAgent

  def test_set_agent_class_manual
    assert_equal TestTestAgent, self.class.agent_class
  end
end

class ManuallySetSymbolNameAgentTest < ActionAI::TestCase
  tests :test_test_agent

  def test_set_agent_class_manual_using_symbol
    assert_equal TestTestAgent, self.class.agent_class
  end
end

class ManuallySetStringNameAgentTest < ActionAI::TestCase
  tests "test_test_agent"

  def test_set_agent_class_manual_using_string
    assert_equal TestTestAgent, self.class.agent_class
  end
end
