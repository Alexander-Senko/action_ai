# frozen_string_literal: true

require "abstract_unit"

require "action_dispatch"
require "active_support/time"

require "agents/base_agent"
require "agents/proc_agent"
require "agents/asset_agent"

class AgentTest < ActiveSupport::TestCase
  include Rails::Dom::Testing::Assertions::DomAssertions

  setup do
    @original_asset_host = ActionAI::Agent.asset_host
    @original_assets_dir = ActionAI::Agent.assets_dir
  end

  teardown do
    ActionAI::Agent.asset_host = @original_asset_host
    ActionAI::Agent.assets_dir = @original_assets_dir
  end

  test "method call to agent action does not raise error" do
    assert_nothing_raised { BaseAgent.welcome }
  end

  test "ask() renders the template using the method being processed" do
    response = BaseAgent.welcome
    assert_equal("Welcome", response.content)
  end

  test "ask() doesn't set the agent as a controller in the execution context" do
    ActiveSupport::ExecutionContext.clear
    assert_nil ActiveSupport::ExecutionContext.to_h[:controller]
    BaseAgent.welcome
    assert_nil ActiveSupport::ExecutionContext.to_h[:controller]
  end

  # Attachments
  test "attachment with content" do
    response = BaseAgent.attachment_with_content.content
    assert_equal(1, response.attachments.length)
    assert_equal("base_agent.rb", response.attachments[0].filename)
  end

  test "translations are scoped properly" do
    with_translation "en", base_agent: { prompt_with_translations: { greet_user: "Hello %{name}!" } } do
      response = BaseAgent.prompt_with_translations
      assert_equal "Hello lifo!", response.content
    end
  end

  test "attachments added after AI was called are for the next call" do
    class LateAttachmentAgent < ActionAI::Agent
      def welcome
        ask "yay"
        attachments << __FILE__
      end
    end

    assert_nothing_raised { LateAttachmentAgent.welcome.message }
    assert_equal [__FILE__], LateAttachmentAgent.welcome.send(:processed_agent).attachments
  end

  test "accessing attachments doesn't work after AI was called" do
    class LateAttachmentAccessorAgent < ActionAI::Agent
      def welcome
        attachments << __FILE__
        ask "yay"
      end
    end

    assert_nothing_raised { LateAttachmentAccessorAgent.welcome.message }
    assert_empty LateAttachmentAccessorAgent.welcome.send(:processed_agent).attachments
  end

  # Class level API with method missing
  test "should respond to action methods" do
    assert_respond_to BaseAgent, :welcome
    assert_not_respond_to BaseAgent, :ask
  end

  # Rendering
  test "you can specify a different template for explicit render" do
    prompt = BaseAgent.explicit_different_template("explicit_template").content
    assert_equal("HTML Explicit Template", prompt.strip)
  end

  test "you can specify a different layout" do
    prompt = BaseAgent.different_layout("different_layout").content
    assert_equal("HTML -- HTML", prompt.strip)
  end

  test "assets tags should use ActionAI's asset_host settings" do
    ActionAI::Agent.config.asset_host = "http://global.com"
    ActionAI::Agent.config.assets_dir = "global/"

    response = AssetAgent.welcome

    assert_dom_equal(%{<img src="http://global.com/images/dummy.png" />}, response.content.strip)
  end

  test "assets tags should use a Agent's asset_host settings when available" do
    ActionAI::Agent.config.asset_host = "http://global.com"
    ActionAI::Agent.config.assets_dir = "global/"

    TempAssetAgent = Class.new(AssetAgent) do
      self.agent_name = "asset_agent"
      self.asset_host = "http://local.com"
    end

    response = TempAssetAgent.welcome

    assert_dom_equal(%{<img src="http://local.com/images/dummy.png" />}, response.content.to_s.strip)
  end

  test "the return value of agent methods is not relevant" do
    response = BaseAgent.with_nil_as_return_value
    assert_equal("Welcome", response.content.strip)
  end

  test "proc default values are not evaluated when overridden" do
    with_default BaseAgent, model: -> { flunk } do
      response = ProcAgent.welcome
      assert_equal "echo", response.model_id
    end
  end

  test "modifying the prompt with a before_action" do
    class BeforeActionAgent < ActionAI::Agent
      before_action :add_special_header!

      def welcome
        ask "#{@header} prompt"
      end

      private
        def add_special_header!
          @header = "Wow, so special"
        end
    end

    assert_equal("Wow, so special prompt", BeforeActionAgent.welcome.content)
  end

  test "continue interaction with an after_action" do
    class AfterActionAgent < ActionAI::Agent
      after_action :review_results

      def welcome ; end

      private
        def review_results
          ask "Review and correct the results"
        end
    end

    assert_equal("Review and correct the results", AfterActionAgent.welcome.content)
  end

  test "action methods should be refreshed after defining new method" do
    class FooAgent < ActionAI::Agent
      # This triggers action_methods.
      respond_to?(:foo)

      def notify
      end
    end

    assert_equal Set.new(["notify"]), FooAgent.action_methods
  end

  test "agent can be anonymous" do
    agent = Class.new(ActionAI::Agent) do
      def welcome
      end
    end

    assert_equal "anonymous", agent.agent_name

    assert_equal "Anonymous agent body", agent.welcome.content.strip
  end

  test "notification for process" do
    expected_payload = { agent: "BaseAgent", action: :welcome, args: [] }

    assert_notifications_count("process.action_ai", 1) do
      assert_notification("process.action_ai", expected_payload) do
        BaseAgent.welcome.run
      end
    end
  end

  private
    def with_default(klass, new_values)
      old = klass.default_params
      klass.default(new_values)
      yield
    ensure
      klass.default_params = old
    end

    def with_translation(locale, data)
      I18n.backend.store_translations(locale, data)
      yield
    ensure
      I18n.backend.reload!
    end
end

class PreviewTest < ActiveSupport::TestCase
  class A < ActionAI::Preview; end

  module B
    class A < ActionAI::Preview; end
    class C < ActionAI::Preview; end
  end

  class C < ActionAI::Preview; end

  test "all() returns agents in alphabetical order" do
    ActionAI::Preview.stub(:descendants, [C, A, B::C, B::A]) do
      agents = ActionAI::Preview.all
      assert_equal [A, B::A, B::C, C], agents
    end
  end
end
