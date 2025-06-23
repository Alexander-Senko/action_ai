# frozen_string_literal: true

require "active_job"

module ActionAI
  # = Action AI \ExecutionJob
  #
  # The +ActionAI::ExecutionJob+ class is used when you
  # want to execute AI-powered jobs outside of the request-response cycle. It supports
  # executing either parameterized or normal actions.
  #
  # Exceptions are rescued and handled by the agent class.
  class ExecutionJob < ActiveJob::Base # :nodoc:
    queue_as do
      arguments.first.constantize
        .execute_later_queue_name
    end

    rescue_from StandardError, with: :handle_exception_with_agent_class

    def perform(agent, action, args: [], kwargs: {}, params: nil)
      agent.constantize
        .then { params ? it.with(params) : it }
        .public_send(action, *args, **kwargs)
        .run
    end

    private
      # "Deserialize" the agent class name by hand in case another argument
      # (like a Global ID reference) raised DeserializationError.
      def agent_class
        [@serialized_arguments, arguments]
          .filter_map { Array(it).first }
          .first&.constantize
      end

      def handle_exception_with_agent_class(exception)
        agent_class&.handle_exception exception or
          raise exception
      end
  end
end
