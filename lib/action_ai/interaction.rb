# frozen_string_literal: true

require "delegate"

module ActionAI
  # = Action AI \Interaction
  #
  # The +ActionAI::Interaction+ class is used by
  # ActionAI::Agent when creating a new agent.
  # <tt>Interaction</tt> is a wrapper (+Delegator+ subclass) around a lazy
  # created +RubyLLM::Message+. You can get direct access to the
  # +RubyLLM::Message+ or schedule the job to be executed
  # through Active Job.
  #
  #   Generator.code(task)         # an ActionAI::Interaction object
  #   Generator.code(task).content # executes and returns the result
  #   Generator.code(task).later   # enqueue execution as a job through Active Job
  #   Generator.code(task).message # a RubyLLM::Message object
  class Interaction < Delegator
    def initialize(agent_class, action, *args) # :nodoc:
      @agent_class, @action, @args = agent_class, action, args

      # The AI interaction is only processed if we try to call any methods on it.
      # Typical usage will leave it unloaded and call +later+.
      @processed_agent = nil
      @message = nil
    end
    ruby2_keywords(:initialize)

    # Method calls are delegated to the RubyLLM::Message that's ready to execute.
    def __getobj__ # :nodoc:
      @message ||= processed_agent.handle_exceptions do
        processed_agent.run_callbacks(:execution) do
          processed_agent.message
        end
      end.presence
    end

    # Unused except for delegator internals (dup, marshalling).
    def __setobj__(message) # :nodoc:
      @message = message
    end

    # Returns the resulting RubyLLM::Message
    def message
      __getobj__
    end

    # Was the delegate loaded, causing the action to be processed?
    def processed?
      @processed_agent || @message
    end

    def run = message

    # Enqueues the action to be executed through Active Job.
    #
    #   Generator.code(task).later
    #   Generator.code(task).later(wait: 1.hour)
    #   Generator.code(task).later(wait_until: 10.hours.from_now)
    #   Generator.code(task).later(priority: 10)
    #
    # Options:
    #
    # * <tt>:wait</tt> - Enqueue the action to be executed with a delay.
    # * <tt>:wait_until</tt> - Enqueue the action to be executed at (after) a specific date / time.
    # * <tt>:queue</tt> - Enqueue the action on the specified queue.
    # * <tt>:priority</tt> - Enqueues the action with the specified priority
    #
    # By default, the action will be enqueued using ActionAI::ExecutionJob on
    # the default queue. Agent classes can customize the queue name used for the default
    # job by assigning a +execute_later_queue_name+ class variable, or provide a custom job
    # by assigning a +execution_job+. When a custom job is used, it controls the queue name.
    #
    #   class CostlyAgent < ApplicationAI
    #     self.execution_job = CostlyExecutionJob
    #   end
    def later(...) = enqueue_execution(...)

    ruby2_keywords def method_missing(method, *args, &)
      case method.name
      when *@agent_class.action_methods
        processed_agent.process(@action = method, *(@args = args), &)
        self
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      [
        method.name.in?(@agent_class.action_methods),
        super,
      ].any?
    end

    private
      # Returns the processed Agent instance. We keep this instance
      # on hand so we can run callbacks and delegate exception handling to it.
      def processed_agent
        @processed_agent ||= @agent_class.new.tap do
          it.process @action, *@args
        end
      end

      def enqueue_execution(...)
        if processed?
          ::Kernel.raise "You've used the AI agent before asking to " \
            "call it later, so you may have made local changes that would " \
            "be silently lost if we enqueued a job to execute it. Why? Only " \
            "the agent method *arguments* are passed with the execution job! " \
            "Do not use the AI agent in any way if you mean to call it " \
            "later. Workarounds: 1. don't touch the agent before calling " \
            "#later, 2. only touch the agent *within your agent " \
            "method*, or 3. use a custom Active Job instead of #later."
        else
          @agent_class.execution_job.set(...).perform_later(
            @agent_class.name, @action.to_s, args: @args)
        end
      end
  end
end
