# frozen_string_literal: true

require "abstract_unit"
require "action_controller"

class AssetHostAgent < ActionAI::Agent
  def prompt_with_asset
  end
end

class AssetHostTest < ActionAI::TestCase
  def setup
    AssetHostAgent.configure do |c|
      c.asset_host = "http://www.example.com"
    end
  end

  def test_asset_host_as_string
    message = AssetHostAgent.prompt_with_asset
    assert_dom_equal '<img src="http://www.example.com/images/somelogo.png" />', message.content.strip
  end

  def test_asset_host_as_one_argument_proc
    AssetHostAgent.config.asset_host = Proc.new { |source|
      if source.start_with?("/images")
        "http://images.example.com"
      end
    }
    message = AssetHostAgent.prompt_with_asset
    assert_dom_equal '<img src="http://images.example.com/images/somelogo.png" />', message.content.strip
  end
end
