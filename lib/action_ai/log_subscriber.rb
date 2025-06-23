# frozen_string_literal: true

require "active_support/log_subscriber"

module ActionAI
  # = Action AI \LogSubscriber
  #
  # Implements the ActiveSupport::LogSubscriber for logging notifications when
  # a prompt is executed.
  class LogSubscriber < ActiveSupport::LogSubscriber
    # A prompt was processed.
    def process(event)
      debug do
        agent  = event.payload[:agent]
        action = event.payload[:action]
        "#{agent}##{action}: executed prompt in #{event.duration.round(1)}ms"
      end
    end
    subscribe_log_level :process, :debug

    # Use the logger configured for ActionAI::Agent.
    def logger
      ActionAI::Agent.logger
    end
  end
end

ActionAI::LogSubscriber.attach_to :action_ai
