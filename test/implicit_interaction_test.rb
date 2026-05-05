# frozen_string_literal: true

require "abstract_unit"

class ImplicitInteractionAgent < ActionAI::Agent
  def no_ask
  end

  def explicit_ask
    ask "Explicit prompt"
  end

  def explicit_ask_with_template
    ask render("welcome")
  end

  def multiple_asks
    ask "First prompt"
    ask "Second prompt"
  end

  def ask_with_side_effects
    @side_effect_ran = true
    ask "Prompt with side effects"
  end

  def no_ask_but_sets_variable
    @some_var = "set"
  end
end

class ImplicitInteractionTest < ActionAI::TestCase
  test "action without explicit ask renders template implicitly" do
    response = ImplicitInteractionAgent.no_ask
    assert_equal "Implicit prompt", response.message.content.strip
  end

  test "action with explicit ask uses the provided prompt, not the template" do
    response = ImplicitInteractionAgent.explicit_ask
    assert_equal "Explicit prompt", response.message.content
  end

  test "action with explicit ask using render uses rendered template content" do
    response = ImplicitInteractionAgent.explicit_ask_with_template
    assert_equal "Welcome", response.message.content.strip
  end

  test "action without ask uses default template rendering" do
    response = ImplicitInteractionAgent.no_ask_but_sets_variable
    assert_equal "Variable is set", response.message.content.strip
  end

  test "action that calls ask multiple times uses the last ask result" do
    response = ImplicitInteractionAgent.multiple_asks
    assert_equal "Second prompt", response.message.content
  end

  test "implicit ask does not run when action already called ask" do
    agent = Class.new(ImplicitInteractionAgent) do
      cattr_accessor :ask_count, default: 0

      def ask(...)
        self.ask_count += 1
        super
      end
    end

    agent.explicit_ask.run
    assert_equal 1, agent.ask_count
  end

  test "implicit ask is triggered exactly once when no ask is called" do
    stub_any_instance(ImplicitInteractionAgent) do |instance|
      asks = []
      original_ask = instance.method(:ask)
      instance.stub(:ask, ->(prompt = nil, **kwargs, &block) {
        asks << prompt
        original_ask.call(prompt || instance.send(:prompt), **kwargs, &block)
      }) do
        ImplicitInteractionAgent.no_ask.run
        assert_equal 1, asks.size
      end
    end
  end

  test "action without ask returns an interaction that responds to message" do
    interaction = ImplicitInteractionAgent.no_ask
    assert_respond_to interaction, :message
  end

  test "action with explicit ask still returns a valid interaction" do
    interaction = ImplicitInteractionAgent.explicit_ask
    assert_respond_to interaction, :message
  end

  test "side effects in action body are preserved even with implicit ask" do
    interaction = ImplicitInteractionAgent.ask_with_side_effects
    agent = interaction.send(:processed_agent)
    assert agent.instance_variable_get(:@side_effect_ran)
  end
end
