# frozen_string_literal: true

require "abstract_unit"
require "active_job"
require "agents/params_agent"

class ParameterizedTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class DummyExecutionJob < ActionAI::ExecutionJob
  end

  setup do
    @previous_logger = ActiveJob::Base.logger
    ActiveJob::Base.logger = Logger.new(nil)

    @interaction = ParamsAgent.with(inviter: "david@basecamp.com", invitee: "jason@basecamp.com").invitation
  end

  teardown do
    ActiveJob::Base.logger = @previous_logger
  end

  test "parameterized prompt" do
    assert_equal("david@basecamp.com welcomes jason@basecamp.com to the project", @interaction.content)
  end

  test "degrade gracefully when .with is not called" do
    @interaction = ParamsAgent.invitation

    assert_equal(" welcomes  to the project", @interaction.content)
  end

  test "enqueue the job with params" do
    args = [
      "ParamsAgent",
      "invitation",
      params: { inviter: "david@basecamp.com", invitee: "jason@basecamp.com" },
      args: [],
    ]
    assert_performed_with(job: ActionAI::ExecutionJob, args: args) do
      @interaction.later
    end
  end

  test "respond_to?" do
    agent = ParamsAgent.with(inviter: "david@basecamp.com", invitee: "jason@basecamp.com")

    assert_respond_to agent, :invitation
    assert_not_respond_to agent, :anything

    invitation = agent.method(:invitation)
    assert_equal Method, invitation.class

    assert_raises(NameError) do
      invitation = agent.method(:anything)
    end
  end

  test "should enqueue a parameterized request with the correct execution job" do
    args = [
      "ParamsAgent",
      "invitation",
      params: { inviter: "david@basecamp.com", invitee: "jason@basecamp.com" },
      args: [],
    ]

    with_execution_job DummyExecutionJob do
      assert_performed_with(job: DummyExecutionJob, args: args) do
        @interaction.later
      end
    end
  end

  private
    def with_execution_job(job)
      old_execution_job = ParamsAgent.execution_job
      ParamsAgent.execution_job = job
      yield
    ensure
      ParamsAgent.execution_job = old_execution_job
    end
end
