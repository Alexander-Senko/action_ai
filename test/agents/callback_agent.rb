# frozen_string_literal: true

CallbackAgentError = Class.new(StandardError)
class CallbackAgent < ActionAI::Agent
  cattr_accessor :rescue_from_error
  cattr_accessor :after_execution_instance
  cattr_accessor :around_execution_instance
  cattr_accessor :abort_before_execution
  cattr_accessor :around_handles_error

  rescue_from CallbackAgentError do |error|
    @@rescue_from_error = error
  end

  before_execution do
    throw :abort if @@abort_before_execution
  end

  after_execution do
    @@after_execution_instance = self
  end

  around_execution do |agent, block|
    @@around_execution_instance = self
    block.call
  rescue StandardError
    raise unless @@around_handles_error
  end

  def test_message(*)
    ask "Test prompt"
  end

  def test_raise_action
    raise CallbackAgentError, "boom action processing"
  end
end
