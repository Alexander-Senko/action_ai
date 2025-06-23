# frozen_string_literal: true

require "active_support/core_ext/array/extract_options"
require "active_job"
require "ruby_llm/tester"

RubyLLM.configure do
  it.default_model = "echo"
end

module ActionAI
  # Provides a list of prompts that have been executed by RubyLLM::Tester
  singleton_class.delegate :interactions, to: RubyLLM::Tester

  # Provides helper methods for testing Action AI, including #assert_ai_prompts
  # and #assert_no_ai_prompts.
  module TestHelper
    include ActiveJob::TestHelper

    # Asserts that the number of AI prompts executed matches the given number.
    #
    #   def test_prompts
    #     assert_ai_prompts 0
    #     Generator.code(task).run
    #     assert_ai_prompts 1
    #     Generator.code(task).run
    #     assert_ai_prompts 2
    #   end
    #
    # If a block is passed, that block should cause the specified number of
    # prompts to be executed.
    #
    #   def test_ai_prompts_again
    #     assert_ai_prompts 1 do
    #       Generator.code(task).run
    #     end
    #
    #     assert_ai_prompts 2 do
    #       Generator.code(task).run
    #       Generator.code(task).later
    #     end
    #   end
    def assert_ai_prompts(number, &block)
      if block_given?
        diff = capture_ai_prompts(&block).length
        assert_equal number, diff, "#{number} prompts expected, but #{diff} were executed"
      else
        assert_equal number, ActionAI.interactions.size
      end
    end

    # Asserts that no AI prompts have been executed.
    #
    #   def test_prompts
    #     assert_no_ai_prompts
    #     Generator.code(task).run
    #     assert_ai_prompts 1
    #   end
    #
    # If a block is passed, that block should not cause any prompts to be executed.
    #
    #   def test_prompts_again
    #     assert_no_ai_prompts do
    #       # No prompts should be executed from this block
    #     end
    #   end
    #
    # Note: This assertion is simply a shortcut for:
    #
    #   assert_ai_prompts 0, &block
    def assert_no_ai_prompts(&block)
      assert_ai_prompts 0, &block
    end

    # Asserts that the number of AI jobs enqueued for later processing matches
    # the given number.
    #
    #   def test_jobs
    #     assert_enqueued_ai_jobs 0
    #     Generator.code(task).later
    #     assert_enqueued_ai_jobs 1
    #     Generator.code(task).later
    #     assert_enqueued_ai_jobs 2
    #   end
    #
    # If a block is passed, that block should cause the specified number of
    # jobs to be enqueued.
    #
    #   def test_jobs_again
    #     assert_enqueued_ai_jobs 1 do
    #       Generator.code(task).later
    #     end
    #
    #     assert_enqueued_ai_jobs 2 do
    #       Generator.code(task).later
    #       Generator.code(task).later
    #     end
    #   end
    def assert_enqueued_ai_jobs(number, &block)
      assert_enqueued_jobs(number, only: ->(job) { ai_job_filter(job) }, &block)
    end

    # Asserts that a specific AI job has been enqueued, optionally
    # matching arguments and/or params.
    #
    #   def test_job
    #     Generator.code.later
    #     assert_enqueued_ai_job_with Generator, :code
    #   end
    #
    #   def test_job_with_parameters
    #     Generator.with(context: "MVP").later
    #     assert_enqueued_ai_job_with Generator, :code, params: { context: "MVP" }
    #   end
    #
    #   def test_job_with_arguments
    #     Generator.code(task).later
    #     assert_enqueued_ai_job_with Generator, :code, args: [task]
    #   end
    #
    #   def test_job_with_named_arguments
    #     Generator.code(task:).later
    #     assert_enqueued_ai_job_with Generator, :code, args: [{task:}]
    #   end
    #
    #   def test_job_with_parameters_and_arguments
    #     Generator.with(context: "MVP").code(task).later
    #     assert_enqueued_ai_job_with Generator, :code, params: { context: "MVP" }, args: [task]
    #   end
    #
    #   def test_job_with_parameters_and_named_arguments
    #     Generator.with(context: "MVP").code(task:).later
    #     assert_enqueued_ai_job_with Generator, :code, params: { context: "MVP" }, args: [{task:}]
    #   end
    #
    #   def test_job_with_parameterized_agent
    #     Generator.with(context: "MVP").code.later
    #     assert_enqueued_ai_job_with Generator.with(context: "MVP"), :code
    #   end
    #
    #   def test_job_with_matchers
    #     Generator.with(context: "MVP").code(task).later
    #     assert_enqueued_ai_job_with Generator, :code,
    #       params: ->(params) { /mvp/i.match?(params[:context]) },
    #       args: ->(args) { task == args[0] }
    #   end
    #
    # If a block is passed, that block should cause the specified job
    # to be enqueued.
    #
    #   def test_job_in_block
    #     assert_enqueued_ai_job_with Generator, :code do
    #       Generator.code(task).later
    #     end
    #   end
    #
    # If +args+ is provided as a Hash, a parameterized job is matched.
    #
    #   def test_parameterized_job
    #     assert_enqueued_ai_job_with Generator, :code,
    #       args: {context: "MVP"} do
    #       Generator.with(context: "MVP").code.later
    #     end
    #   end
    def assert_enqueued_ai_job_with(agent, method, params: nil, args: nil, queue: nil, &block)
      if agent.is_a? ActionAI::Parameterized::Agent
        params = agent.instance_variable_get(:@params)
        agent = agent.instance_variable_get(:@agent)
      end

      args = Array(args) unless args.is_a?(Proc)
      queue ||= agent.execute_later_queue_name || ActiveJob::Base.default_queue_name

      expected = ->(job_args) do
        job_kwargs = job_args.extract_options!

        [agent.to_s, method.to_s] == job_args &&
          params === job_kwargs[:params] && args === job_kwargs[:args]
      end

      assert_enqueued_with(job: agent.execution_job, args: expected, queue: queue.to_s, &block)
    end

    # Asserts that no AI jobs are enqueued for later processing.
    #
    #   def test_no_jobs
    #     assert_no_enqueued_ai_jobs
    #     Generator.code(task).later
    #     assert_enqueued_ai_jobs 1
    #   end
    #
    # If a block is provided, it should not cause any AI jobs to be enqueued.
    #
    #   def test_no_jobs
    #     assert_no_enqueued_ai_jobs do
    #       # No AI jobs should be enqueued from this block
    #     end
    #   end
    def assert_no_enqueued_ai_jobs(&block)
      assert_enqueued_ai_jobs 0, &block
    end

    # Executes all enqueued AI jobs. If a block is given, executes all of the jobs
    # that were enqueued throughout the duration of the block. If a block is
    # not given, executes all the enqueued jobs up to this point in the test.
    #
    #   def test_execute_enqueued_jobs
    #     perform_enqueued_ai_jobs do
    #       Generator.code(task).later
    #     end
    #
    #     assert_ai_prompts 1
    #   end
    #
    #   def test_execute_enqueued_jobs_without_block
    #     Generator.code(task).later
    #
    #     perform_enqueued_ai_jobs
    #
    #     assert_ai_prompts 1
    #   end
    #
    # If the +:queue+ option is specified,
    # then only the prompts enqueued to a specific queue will be performed.
    #
    #   def test_execute_enqueued_jobs_with_queue
    #     perform_enqueued_ai_jobs queue: :external_agents do
    #       Generator.execution_later_queue_name = :external_agents
    #       Generator.code(task).later # will be performed
    #       Notifier.execution_later_queue_name = :internal_agents
    #       Notifier.welcome.later # will not be performed
    #     end
    #
    #     assert_ai_prompts 1
    #   end
    #
    # If the +:at+ option is specified, then only executes prompts enqueued to execution
    # immediately or before the given time.
    def perform_enqueued_ai_jobs(queue: nil, at: nil, &block)
      perform_enqueued_jobs(only: ->(job) { ai_job_filter(job) }, queue: queue, at: at, &block)
    end

    # Returns any AI prompts that are executed in the block.
    #
    #   def test_ai_prompts
    #     prompts = capture_ai_prompts do
    #       Generator.code(task).content
    #     end
    #     assert_match /Write .*code/, prompts.first.content
    #
    #     prompts = capture_ai_prompts do
    #       Generator.code(task).content
    #       Generator.code(task).later
    #     end
    #     assert_match /Write .*code/, prompts.first.content
    #   end
    def capture_ai_prompts(&block)
      original_count = ActionAI.interactions.size
      perform_enqueued_ai_jobs(&block)
      new_count = ActionAI.interactions.size
      diff = new_count - original_count
      ActionAI.interactions.last(diff)
    end

    private
      def ai_job_filter(job)
        job_class = job.is_a?(Hash) ? job.fetch(:job) : job.class

        Agent.descendants.map(&:execution_job).include?(job_class)
      end
  end
end
