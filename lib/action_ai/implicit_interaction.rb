# frozen_string_literal: true

module ActionAI
  # # Action AI Implicit Interaction
  #
  # Handles implicit interactions for an agent action that does not explicitly
  # respond with `ask`.
  #
  # If no explicit `ask` is performed by the action, the implicit response is
  # to call `ask` with the default prompt rendering.
  module ImplicitInteraction
    def send_action(...)
      super
        .tap { default_interaction unless performed? }
    end

    def default_interaction = ask
  end
end
