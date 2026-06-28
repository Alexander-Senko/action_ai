# frozen_string_literal: true

require "abstract_unit"
require "ruby_llm/providers/test"

module RubyLLM
  class TestProviderTest < ActiveSupport::TestCase
    MessageStub = Struct.new :role, :content
    ModelStub   = Struct.new :id

    test "provider is local" do
      assert Providers::Test.local?
    end

    test "complete returns an assistant message for the echo model" do
      response = provider.complete([
        MessageStub.new(:user, "Hello"),
        MessageStub.new(:user, "World"),
      ], model:)

      assert_equal :assistant,       response.role
      assert_equal "echo",           response.model_id
      assert_equal "Hello\n\nWorld", response.content
    end

    test "complete yields generated response content" do
      content = nil

      provider.complete([
        MessageStub.new(:user, "Content"),
      ], model:) { content = it }

      assert_equal "Content", content
    end

    test "complete echoes only messages after the last assistant reply" do
      response = provider.complete([
        MessageStub.new(:user,      "One"),
        MessageStub.new(:assistant, "One"),
        MessageStub.new(:system,    "Instructions"),
        MessageStub.new(:user,      "Two"),
        MessageStub.new(:user,      "Three"),
      ], model:)

      assert_equal "Instructions\n\nTwo\n\nThree", response.content
    end

    test "complete raises when model response handler does not exist" do
      model = ModelStub.new("unknown")

      assert_raises(NoMethodError) do
        provider.complete([
          MessageStub.new(:user, "Hello"),
        ], model:)
      end
    end

    test "list_models exposes the echo model" do
      models = Providers::Test.new.list_models

      assert_equal %w[echo],               models.map(&:id)
      assert_equal [Providers::Test.slug], models.map(&:provider).uniq
    end

    def provider = @provider ||= Providers::Test.new
    def model    = @model    ||= RubyLLM.models.find("echo")
  end
end
