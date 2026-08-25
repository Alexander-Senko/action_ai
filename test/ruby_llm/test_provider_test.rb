# frozen_string_literal: true

require "abstract_unit"
require "ruby_llm/providers/test"

module RubyLLM
  class TestProviderTest < ActiveSupport::TestCase
    test "provider is local" do
      assert Providers::Test.local?
    end

    test "complete returns an assistant message for the echo model" do
      response = provider.complete([
        Message.new(role: :user, content: "Hello"),
        Message.new(role: :user, content: "World"),
      ], model:, tools: [], temperature: nil)

      assert_equal :assistant,       response.role
      assert_equal "echo",           response.model
      assert_equal "Hello\n\nWorld", response.content
    end

    test "complete yields generated response content" do
      response = nil

      provider.complete([
        Message.new(role: :user, content: "Content"),
      ], model:, tools: [], temperature: nil) { response = it }

      assert_equal "Content", response.content
    end

    test "complete echoes only messages after the last assistant reply" do
      response = provider.complete([
        Message.new(role: :user,      content: "One"),
        Message.new(role: :assistant, content: "One"),
        Message.new(role: :system,    content: "Instructions"),
        Message.new(role: :user,      content: "Two"),
        Message.new(role: :user,      content: "Three"),
      ], model:, tools: [], temperature: nil)

      assert_equal "Instructions\n\nTwo\n\nThree", response.content
    end

    include Memery

    memoize def provider = Providers::Test.new(RubyLLM.config)
    memoize def model    = RubyLLM.models.find("echo")
  end
end
