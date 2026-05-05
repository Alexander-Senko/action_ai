# frozen_string_literal: true

require "abstract_unit"

class AutoLayoutAgent < ActionAI::Agent
  def hello
  end

  def spam
    @world = "Earth"
    ask render(inline: "Hello, <%= @world %>", layout: "spam")
  end

  def nolayout
    @world = "Earth"
    ask render(inline: "Hello, <%= @world %>", layout: false)
  end
end

class ExplicitLayoutAgent < ActionAI::Agent
  layout "spam", except: [:logout]

  def signup
  end

  def logout
  end
end

class LayoutAgentTest < ActiveSupport::TestCase
  def test_should_pickup_default_layout
    prompt = AutoLayoutAgent.hello
    assert_equal "Hello from layout Inside", prompt.content.strip
  end

  def test_should_pickup_layout_given_to_render
    prompt = AutoLayoutAgent.spam
    assert_equal "Spammer layout Hello, Earth", prompt.content.strip
  end

  def test_should_respect_layout_false
    prompt = AutoLayoutAgent.nolayout
    assert_equal "Hello, Earth", prompt.content.strip
  end

  def test_explicit_class_layout
    prompt = ExplicitLayoutAgent.signup
    assert_equal "Spammer layout We do not spam", prompt.content.strip
  end

  def test_explicit_layout_exceptions
    prompt = ExplicitLayoutAgent.logout
    assert_equal "You logged out", prompt.content.strip
  end
end
