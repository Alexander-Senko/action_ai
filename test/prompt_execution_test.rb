# frozen_string_literal: true

require "abstract_unit"
require "active_job"
require "agents/delayed_agent"

class PromptExecutionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @previous_logger = ActiveJob::Base.logger

    ActiveJob::Base.logger = Logger.new(nil)

    ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = true
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true

    DelayedAgent.last_error = nil
    DelayedAgent.last_rescue_from_instance = nil

    @interaction = DelayedAgent.test_message(1, 2, 3)
  end

  teardown do
    ActiveJob::Base.logger = @previous_logger

    DelayedAgent.last_error = nil
    DelayedAgent.last_rescue_from_instance = nil
  end

  test "should have a message" do
    assert @interaction.message
  end

  test "its message should be a RubyLLM::Message" do
    assert_equal RubyLLM::Message, @interaction.message.class
  end

  test "should respond to .later" do
    assert_respond_to @interaction, :later
  end

  test "should respond to .run" do
    assert_respond_to @interaction, :run
  end

  test "should enqueue execution with a delay" do
    travel_to Time.new(2004, 11, 24, 1, 4, 44) do
      assert_performed_with(job: ActionAI::ExecutionJob, at: Time.current + 10.minutes, args: ["DelayedAgent", "test_message", args: [1, 2, 3]]) do
        @interaction.later wait: 10.minutes
      end
    end
  end

  test "should enqueue execution with a priority" do
    job = @interaction.later priority: 10
    assert_equal 10, job.priority
  end

  test "should enqueue execution at a specific time" do
    later_time = Time.current + 1.hour
    assert_performed_with(job: ActionAI::ExecutionJob, at: later_time, args: ["DelayedAgent", "test_message", args: [1, 2, 3]]) do
      @interaction.later wait_until: later_time
    end
  end

  test "should enqueue execution on the correct queue" do
    assert_performed_with(job: ActionAI::ExecutionJob, args: ["DelayedAgent", "test_message", args: [1, 2, 3]], queue: "delayed_ai_agents") do
      @interaction.later
    end
  end

  test "should enqueue execution with the correct job" do
    old_execution_job = DelayedAgent.execution_job
    DelayedAgent.execution_job = DummyJob

    assert_performed_with(job: DummyJob, args: ["DelayedAgent", "test_message", args: [1, 2, 3]]) do
      @interaction.later
    end

    DelayedAgent.execution_job = old_execution_job
  end

  class DummyJob < ActionAI::ExecutionJob; end

  test "execution queue can be overridden when enqueuing" do
    assert_performed_with(job: ActionAI::ExecutionJob, args: ["DelayedAgent", "test_message", args: [1, 2, 3]], queue: "another_queue") do
      @interaction.later(queue: :another_queue)
    end
  end

  test "execution queue can be overridden in subclasses" do
    previous_queue_name = DelayedAgent.execute_later_queue_name
    DelayedAgent.execute_later_queue_name = :throttled_ai_agents

    assert_equal :throttled_ai_agents, DelayedAgent.execute_later_queue_name
    assert_equal :ai_agents, ActionAI::Agent.execute_later_queue_name

    assert_performed_with(job: ActionAI::ExecutionJob, args: ["DelayedAgent", "test_message", args: []], queue: "throttled_ai_agents") do
      DelayedAgent.test_message.later
    end
  ensure
    DelayedAgent.execute_later_queue_name = previous_queue_name
  end

  test "later after accessing the message is disallowed" do
    @interaction.message # Load the message, which calls the agent method.

    assert_raise RuntimeError do
      @interaction.later
    end
  end

  test "job delegates error handling to agent" do
    # Superclass not rescued by agent's rescue_from RuntimeError
    message = DelayedAgent.test_raise("StandardError")
    assert_raise(StandardError) { message.later }
    assert_nil DelayedAgent.last_error
    assert_nil DelayedAgent.last_rescue_from_instance

    # Rescued by agent's rescue_from RuntimeError
    message = DelayedAgent.test_raise("DelayedAgentError")
    assert_nothing_raised { message.later }
    assert_equal "boom", DelayedAgent.last_error.message
    assert_kind_of DelayedAgent, DelayedAgent.last_rescue_from_instance
  end

  class DeserializationErrorFixture
    include GlobalID::Identification

    def self.find(id)
      raise "boom, missing find"
    end

    attr_reader :id
    def initialize(id = 1)
      @id = id
    end

    def to_global_id(options = {})
      super app: "foo"
    end
  end

  test "job delegates deserialization errors to agent class" do
    # Inject an argument that can't be deserialized.
    message = DelayedAgent.test_message(DeserializationErrorFixture.new)

    # DeserializationError is raised, rescued, and delegated to the handler
    # on the agent class.
    assert_nothing_raised { message.later }
    assert_equal DelayedAgent, DelayedAgent.last_rescue_from_instance
    assert_equal "Error while trying to deserialize arguments: boom, missing find", DelayedAgent.last_error.message
  end

  test "allows for keyword arguments" do
    assert_performed_with(job: ActionAI::ExecutionJob, args: ["DelayedAgent", "test_kwargs", args: [argument: 1]]) do
      DelayedAgent.test_kwargs(argument: 1)
        .later
    end
  end
end
