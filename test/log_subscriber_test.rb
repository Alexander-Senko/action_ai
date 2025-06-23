# frozen_string_literal: true

require "abstract_unit"
require "agents/base_agent"
require "active_support/log_subscriber/test_helper"
require "action_ai/log_subscriber"

class LogSubscriberTest < ActionAI::TestCase
  include ActiveSupport::LogSubscriber::TestHelper

  def setup
    super
    ActionAI::LogSubscriber.attach_to :action_ai
  end

  def set_logger(logger)
    ActionAI::Agent.logger = logger
  end

  def test_execution_is_notified
    BaseAgent.welcome.run
    wait

    assert_equal 1, @logger.logged(:debug).size
    assert_match(/BaseAgent#welcome: executed prompt in [\d.]+ms/, @logger.logged(:debug).first)
  end
end
