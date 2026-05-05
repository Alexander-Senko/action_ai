# frozen_string_literal: true

require "abstract_unit"
require "agents/callback_agent"
require "active_support/testing/stream"

class ActionAICallbacksTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::Stream

  setup do
    CallbackAgent.rescue_from_error = nil
    CallbackAgent.after_execution_instance = nil
    CallbackAgent.around_execution_instance = nil
    CallbackAgent.abort_before_execution = nil
    CallbackAgent.around_handles_error = nil
  end

  teardown do
    CallbackAgent.rescue_from_error = nil
    CallbackAgent.after_execution_instance = nil
    CallbackAgent.around_execution_instance = nil
    CallbackAgent.abort_before_execution = nil
    CallbackAgent.around_handles_error = nil
  end

  test "run should call after_execution callback and can access received message" do
    prompt = CallbackAgent.test_message
    prompt.run

    assert_kind_of CallbackAgent, CallbackAgent.after_execution_instance
    assert_equal :assistant, CallbackAgent.after_execution_instance.message.role
    assert_equal "Test prompt", CallbackAgent.after_execution_instance.message.content
  end

  test "before_execution can abort the interaction and not run after_execution callbacks" do
    CallbackAgent.abort_before_execution = true

    prompt = CallbackAgent.test_message
    prompt.run

    assert_nil prompt.message
    assert_nil CallbackAgent.after_execution_instance
  end

  test "later should call after_execution callback and can access received message" do
    perform_enqueued_jobs do
      silence_stream($stdout) do
        CallbackAgent.test_message.later
      end
    end
    assert_kind_of CallbackAgent, CallbackAgent.after_execution_instance
    assert_equal :assistant, CallbackAgent.after_execution_instance.message.role
  end

  test "around_execution is called after rescue_from on action processing exceptions" do
    CallbackAgent.around_handles_error = true

    CallbackAgent.test_raise_action.run
    assert CallbackAgent.rescue_from_error
  end

  test "around_execution is called before rescue_from on interaction exceptions" do
    CallbackAgent.around_handles_error = true

    stub_any_instance(CallbackAgent, instance: CallbackAgent.new) do |instance|
      instance.stub(:message, proc { raise "boom execution exception" }) do
        instance.stub(:performed?, true) do
          CallbackAgent.test_message.run
        end
      end
    end

    assert_kind_of CallbackAgent, CallbackAgent.after_execution_instance
    assert_nil CallbackAgent.rescue_from_error
  end
end
