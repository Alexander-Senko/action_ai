# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/stream"

class TestHelperAgent < ActionAI::Agent
  def test
    @world = "Earth"
    ask render(inline: "Hello, <%= @world %>")
  end

  def test_args(name)
    ask render(inline: "Hello, #{name}")
  end

  def test_named_args(name:)
    ask render(inline: "Hello, #{name}")
  end

  def test_parameter_args
    ask render(inline: "All is #{params[:all]}")
  end
end

class CustomExecutionJob < ActionAI::ExecutionJob
end

class CustomExecutionAgent < TestHelperAgent
  self.execution_job = CustomExecutionJob
end

class CustomQueueAgent < TestHelperAgent
  self.execute_later_queue_name = :custom_queue
end

class TestHelperAgentTest < ActionAI::TestCase
  include ActiveSupport::Testing::Stream

  setup do
    @previous_execute_later_queue_name = ActionAI::Agent.execute_later_queue_name
  end

  teardown do
    ActionAI::Agent.execute_later_queue_name = @previous_execute_later_queue_name
  end

  def test_setup_sets_right_action_ai_options
    assert_equal "echo", RubyLLM.config.default_model
    assert_equal [], ActionAI.interactions
  end

  def test_setup_creates_the_expected_agent
    assert_kind_of RubyLLM::Message, @expected
  end

  def test_agent_class_is_correctly_inferred
    assert_equal TestHelperAgent, self.class.agent_class
  end

  def test_determine_default_agent_raises_correct_error
    assert_raise(ActionAI::NonInferrableAgentError) do
      self.class.determine_default_agent("NotAAgentTest")
    end
  end

  def test_read_fixture
    assert_equal ["Welcome!"], read_fixture("welcome")
  end

  def test_assert_ai_prompts
    assert_nothing_raised do
      assert_ai_prompts 1 do
        TestHelperAgent.test.run
      end
    end
  end

  def test_capture_ai_prompts
    assert_nothing_raised do
      prompts = capture_ai_prompts do
        TestHelperAgent.test.run
      end
      prompt = prompts.first
      assert_instance_of RubyLLM::Message, prompt
      assert_equal "Hello, Earth", prompt.content
      assert_equal :user, prompt.role

      prompts = capture_ai_prompts do
        TestHelperAgent.test.run
        TestHelperAgent.test.run
      end
      assert_instance_of Array, prompts
      assert_instance_of RubyLLM::Message, prompts.first
      assert_instance_of RubyLLM::Message, prompts.second
    end
  end

  def test_assert_ai_prompts_with_custom_delivery_job
    assert_nothing_raised do
      assert_ai_prompts(1) do
        silence_stream($stdout) do
          CustomExecutionAgent.test.later
        end
      end
    end
  end

  def test_assert_ai_prompts_with_custom_parameterized_delivery_job
    assert_nothing_raised do
      assert_ai_prompts(1) do
        silence_stream($stdout) do
          CustomExecutionAgent.with(foo: "bar").test_parameter_args.later
        end
      end
    end
  end
end

class AnotherTestHelperAgentTest < ActionAI::TestCase
  tests TestHelperAgent

  def setup
    @test_var = "a value"
  end

  def test_setup_shouldnt_conflict_with_agent_setup
    assert_kind_of RubyLLM::Message, @expected
    assert_equal "a value", @test_var
  end
end

class AdapterIsNotTestAdapterTest < ActionAI::TestCase
  def queue_adapter_for_test
    ActiveJob::QueueAdapters::InlineAdapter.new
  end

  def test_can_execute_prompt_using_any_active_job_adapter
    assert_nothing_raised do
      assert_ai_prompts 1 do
        TestHelperAgent.test.run
      end
    end
  end
end
