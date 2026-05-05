# frozen_string_literal: true

require "abstract_unit"
require "action_controller"

class WelcomeController < ActionController::Base
end

AppRoutes = ActionDispatch::Routing::RouteSet.new

AppRoutes.draw do
  get "/welcome" => "foo#bar", as: "welcome"
  get "/dummy_model" => "foo#baz", as: "dummy_model"
  get "/welcome/greeting", to: "welcome#greeting"
  get "/a/b(/:id)", to: "a#b"
end

class UrlTestAgent < ActionAI::Agent
  include AppRoutes.url_helpers

  default_url_options[:host] = "www.basecamphq.com"

  configure do |c|
    c.assets_dir = "" # To get the tests to pass
  end

  def signed_up_with_url(recipient)
    @recipient   = recipient
    @welcome_url = url_for host: "example.com", controller: "welcome", action: "greeting"
  end

  def exercise_url_for(options)
    @options = options
    @url = url_for(@options)
  end
end

class ActionAIUrlTest < ActionAI::TestCase
  class DummyModel
    def self.model_name
      Struct.new(:route_key, :name).new("dummy_model", nil)
    end

    def persisted?
      false
    end

    def model_name
      self.class.model_name
    end

    def to_model
      self
    end
  end

  def new_message(content, role: :assistant)
    RubyLLM::Message.new content:, role:
  end

  def assert_url_for(expected, options, relative = false)
    expected = "http://www.basecamphq.com#{expected}" if expected.start_with?("/") && !relative
    urls = UrlTestAgent.exercise_url_for(options).content.chomp.split

    assert_equal expected, urls.first
    assert_equal expected, urls.second
  end

  def setup
    @recipient = "test@localhost"
  end

  def test_url_for
    # string
    assert_url_for "http://foo/", "http://foo/"

    # symbol
    assert_url_for "/welcome", :welcome

    # hash
    assert_url_for "/a/b/c", controller: "a", action: "b", id: "c"
    assert_url_for "/a/b/c", { controller: "a", action: "b", id: "c", only_path: true }, true

    # model
    assert_url_for "/dummy_model", DummyModel.new

    # class
    assert_url_for "/dummy_model", DummyModel

    # array
    assert_url_for "/dummy_model", [DummyModel]
  end

  def test_signed_up_with_url
    expected = new_message "Hello there,\n\nMr. #{@recipient}. Please see our greeting at http://example.com/welcome/greeting http://www.basecamphq.com/welcome\n\n<img src=\"/images/somelogo.png\" />"

    created = nil
    assert_nothing_raised { created = UrlTestAgent.signed_up_with_url(@recipient) }
    assert_not_nil created

    assert_equal expected.content, created.content
  end
end
