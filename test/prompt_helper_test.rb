# frozen_string_literal: true

require "abstract_unit"

class HelperAgent < ActionAI::Agent
  def use_prompt_helper
    @text = "But soft! What light through yonder window breaks? It is the east, " \
            "and Juliet is the sun. Arise, fair sun, and kill the envious moon, " \
            "which is sick and pale with grief that thou, her maid, art far more " \
            "fair than she. Be not her maid, for she is envious! Her vestal " \
            "livery is but sick and green, and none but fools do wear it. Cast " \
            "it off!"

    ask render(inline: "<%= block_format @text %>")
  end

  def use_format_paragraph
    @text = "But soft! What light through yonder window breaks?"
    ask render(inline: "<%= format_paragraph @text, 15, 1 %>")
  end

  def use_format_paragraph_with_long_first_word
    @text = "Antidisestablishmentarianism is very long."
    ask render(inline: "<%= format_paragraph @text, 10, 1 %>")
  end

  def use_agent
    ask render(inline: "<%= agent.agent_name %>")
  end

  def use_message
    ask "Hello!"
    ask render(inline: "<%= message.content %>")
  end

  def use_block_format
    @text = <<-TEXT
This is the
first     paragraph.

The second
   paragraph.

* item1 * item2
  * item3
    TEXT

    ask render(inline: "<%= block_format @text %>")
  end

  def use_cache
    ask render(inline: "<% cache(:foo) do %>Greetings from a cache helper block<% end %>")
  end
end

class AgentHelperTest < ActionAI::TestCase
  def test_use_prompt_helper
    message = HelperAgent.use_prompt_helper
    assert_match %r{  But soft!}, message.content
    assert_match %r{east, and\n  Juliet}, message.content
  end

  def test_use_agent
    message = HelperAgent.use_agent
    assert_match "helper_agent", message.content
  end

  def test_use_message
    message = HelperAgent.use_message
    assert_match "Hello!", message.content
  end

  def test_use_format_paragraph
    message = HelperAgent.use_format_paragraph
    assert_match " But soft! What\n light through\n yonder window\n breaks?", message.content
  end

  def test_use_format_paragraph_with_long_first_word
    message = HelperAgent.use_format_paragraph_with_long_first_word
    assert_equal " Antidisestablishmentarianism\n is very\n long.", message.content
  end

  def test_use_block_format
    message = HelperAgent.use_block_format
    expected = <<-TEXT
  This is the first paragraph.

  The second paragraph.

  * item1
  * item2
  * item3
    TEXT
    assert_equal expected, message.content
  end

  def test_use_cache
    assert_nothing_raised do
      message = HelperAgent.use_cache
      assert_equal "Greetings from a cache helper block", message.content
    end
  end

  def helper
    Object.new.extend(ActionAI::PromptHelper)
  end

  def test_block_format
    assert_equal "  * foo\n", helper.block_format(" * foo")
    assert_equal "  * foo\n", helper.block_format("   * foo")
    assert_equal "  * foo\n", helper.block_format("* foo")
    assert_equal "  * foo\n*bar", helper.block_format("* foo*bar")
    assert_equal "  * foo\n  * bar\n", helper.block_format("* foo * bar")
    assert_equal "  *", helper.block_format("* ")
  end
end
