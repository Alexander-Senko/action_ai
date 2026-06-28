# frozen_string_literal: true

require "abstract_unit"
require "ruby_llm/tester"

module RubyLLM
  configure do
    it.default_model = "echo"
  end

  class TesterTest < ActiveSupport::TestCase
    setup do
      Tester.interactions.clear
    end

    teardown do
      Tester.interactions.clear
    end

    test "stores AI interactions in memory" do
      response = RubyLLM.chat.say "Hello!"

      assert_equal "Hello!", response.content
      assert_equal 1,        Tester.interactions.size
      assert_equal :user,    Tester.interactions.last.role
      assert_equal "Hello!", Tester.interactions.last.content
    end

    test "handles multiple interactions" do
      response_1 = RubyLLM.chat.say "One"
      response_2 = RubyLLM.chat.say "Two"

      assert_equal "One",       response_1.content
      assert_equal "Two",       response_2.content
      assert_equal 2,           Tester.interactions.size
      assert_equal %i[user],    Tester.interactions.map(&:role).uniq
      assert_equal %w[One Two], Tester.interactions.map(&:content)
    end

    test "handles multiple interactions in the same chat" do
      chat = RubyLLM.chat

      response_1 = chat.say "One"
      response_2 = chat.say "Two"

      assert_equal "One", response_1.content
      assert_equal "Two", response_2.content
    end

    test "can reset captured interactions" do
      RubyLLM.chat.say "One"
      assert_equal 1, Tester.interactions.size
      RubyLLM.chat.say "Two"
      assert_equal 2, Tester.interactions.size

      Tester.interactions.clear

      assert_empty Tester.interactions
    end
  end
end
