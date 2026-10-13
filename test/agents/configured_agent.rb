# frozen_string_literal: true

class ConfiguredAgent < ActionAI::Agent
  self.agent_name = "base_agent"

  instructions "You are polite."

  def welcome
  end
end

class NamedAgent < ActionAI::Agent
  self.agent_name = "base_agent"

  instructions { "You are #{name}." }

  inputs :name

  def welcome
  end
end

class InheritedConfiguredAgent < ConfiguredAgent
end
