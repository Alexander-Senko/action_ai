# frozen_string_literal: true

class ProcAgent < ActionAI::Agent
  default model: -> { computed_model }

  def welcome
  end

  def computed_model
    "echo"
  end
end
