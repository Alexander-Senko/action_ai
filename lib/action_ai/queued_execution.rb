# frozen_string_literal: true

module ActionAI
  module QueuedExecution
    extend ActiveSupport::Concern

    included do
      class_attribute :execution_job, default: ::ActionAI::ExecutionJob
      class_attribute :execute_later_queue_name, default: :ai_agents
    end
  end
end
