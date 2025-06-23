# frozen_string_literal: true

class DelayedAgentError < StandardError; end

class DelayedAgent < ActionAI::Agent
  self.execute_later_queue_name = :delayed_ai_agents

  cattr_accessor :last_error
  cattr_accessor :last_rescue_from_instance

  rescue_from DelayedAgentError do |error|
    @@last_error = error
    @@last_rescue_from_instance = self
  end

  rescue_from ActiveJob::DeserializationError do |error|
    @@last_error = error
    @@last_rescue_from_instance = self
  end

  def test_message(*)
    ask "Test prompt"
  end

  def test_kwargs(argument:)
    ask "Test prompt with #{argument}"
  end

  def test_raise(klass_name)
    raise klass_name.constantize, "boom"
  end
end
