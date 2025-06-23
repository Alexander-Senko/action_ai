# frozen_string_literal: true

require "fileutils"
require "abstract_unit"
require "agents/base_agent"
require "agents/caching_agent"

CACHE_DIR = "test_cache"
# Don't change '/../temp/' cavalierly or you might hose something you don't want hosed
FILE_STORE_PATH = File.join(__dir__, "/../temp/", CACHE_DIR)

class FragmentCachingAgent < ActionAI::Agent
  abstract!

  def some_action; end
end

class BaseCachingTest < ActiveSupport::TestCase
  def setup
    super
    @store = ActiveSupport::Cache::MemoryStore.new
    @agent = FragmentCachingAgent.new
    @agent.perform_caching = true
    @agent.cache_store = @store
  end
end

class FragmentCachingTest < BaseCachingTest
  def test_read_fragment_with_caching_enabled
    @store.write("views/name", "value")
    assert_equal "value", @agent.read_fragment("name")
  end

  def test_read_fragment_with_caching_disabled
    @agent.perform_caching = false
    @store.write("views/name", "value")
    assert_nil @agent.read_fragment("name")
  end

  def test_fragment_exist_with_caching_enabled
    @store.write("views/name", "value")
    assert @agent.fragment_exist?("name")
    assert_not @agent.fragment_exist?("other_name")
  end

  def test_fragment_exist_with_caching_disabled
    @agent.perform_caching = false
    @store.write("views/name", "value")
    assert_not @agent.fragment_exist?("name")
    assert_not @agent.fragment_exist?("other_name")
  end

  def test_write_fragment_with_caching_enabled
    assert_nil @store.read("views/name")
    assert_equal "value", @agent.write_fragment("name", "value")
    assert_equal "value", @store.read("views/name")
  end

  def test_write_fragment_with_caching_disabled
    assert_nil @store.read("views/name")
    @agent.perform_caching = false
    assert_equal "value", @agent.write_fragment("name", "value")
    assert_nil @store.read("views/name")
  end

  def test_expire_fragment_with_simple_key
    @store.write("views/name", "value")
    @agent.expire_fragment "name"
    assert_nil @store.read("views/name")
  end

  def test_expire_fragment_with_regexp
    @store.write("views/name", "value")
    @store.write("views/another_name", "another_value")
    @store.write("views/primalgrasp", "will not expire ;-)")

    @agent.expire_fragment(/name/)

    assert_nil @store.read("views/name")
    assert_nil @store.read("views/another_name")
    assert_equal "will not expire ;-)", @store.read("views/primalgrasp")
  end

  def test_fragment_for
    @store.write("views/expensive", "fragment content")
    fragment_computed = false

    view_context = @agent.view_context

    buffer = "generated till now -> ".html_safe
    buffer << view_context.send(:fragment_for, "expensive") { fragment_computed = true }

    assert_not fragment_computed
    assert_equal "generated till now -> fragment content", buffer
  end

  def test_html_safety
    assert_nil @store.read("views/name")
    content = "value".html_safe
    assert_equal content, @agent.write_fragment("name", content)

    cached = @store.read("views/name")
    assert_equal content, cached
    assert_equal String, cached.class

    html_safe = @agent.read_fragment("name")
    assert_equal content, html_safe
    assert_predicate html_safe, :html_safe?
  end
end

class FunctionalFragmentCachingTest < BaseCachingTest
  def setup
    super
    @store = ActiveSupport::Cache::MemoryStore.new
    @agent = CachingAgent.new
    @agent.perform_caching = true
    @agent.cache_store = @store
  end

  def test_fragment_caching
    message = @agent.fragment_cache
    expected_body = "\"Welcome\""

    assert_match expected_body, message.content
    assert_match expected_body,
      @store.read("views/caching_agent/fragment_cache:#{template_digest("caching_agent/fragment_cache", "html")}/caching")
  end

  def test_fragment_caching_in_partials
    message = @agent.fragment_cache_in_partials
    expected_body = "Old fragment caching in a partial"
    assert_match(expected_body, message.content)

    assert_match(expected_body,
      @store.read("views/caching_agent/_partial:#{template_digest("caching_agent/_partial", "html")}/caching"))
  end

  def test_skip_fragment_cache_digesting
    message = @agent.skip_fragment_cache_digesting
    expected_body = "No Digest"

    assert_match expected_body, message.content
    assert_match expected_body, @store.read("views/no_digest")
  end

  def test_fragment_caching_options
    time = Time.now
    message = @agent.fragment_caching_options
    expected_body = "No Digest"

    assert_match expected_body, message.content
    Time.stub(:now, time + 11) do
      assert_nil @store.read("views/no_digest")
    end
  end

  def test_fragment_cache_instrumentation
    @agent.enable_fragment_cache_logging = true

    expected_payload = {
      agent: "caching_agent",
      key: [:views, "caching_agent/fragment_cache:#{template_digest("caching_agent/fragment_cache", "html")}", :caching]
    }

    assert_notification("read_fragment.action_ai", expected_payload) do
      @agent.fragment_cache
    end
  ensure
    @agent.enable_fragment_cache_logging = true
  end

  private
    def template_digest(name, format)
      ActionView::Digestor.digest(name: name, format: format, finder: @agent.lookup_context)
    end
end

class CacheHelperOutputBufferTest < BaseCachingTest
  class MockController
    def read_fragment(name, options)
      false
    end

    def write_fragment(name, fragment, options)
      fragment
    end
  end

  def setup
    super
  end

  def test_output_buffer
    output_buffer = ActionView::OutputBuffer.new
    controller = MockController.new
    cache_helper = Class.new do
      def self.controller; end
      def self.output_buffer; end
      def self.output_buffer=; end
    end
    cache_helper.extend(ActionView::Helpers::CacheHelper)

    cache_helper.stub :controller, controller do
      cache_helper.stub :output_buffer, output_buffer do
        assert_nothing_raised do
          cache_helper.send :fragment_for, "Test fragment name", "Test fragment", &Proc.new { nil }
        end
      end
    end
  end
end

class ViewCacheDependencyTest < BaseCachingTest
  class NoDependenciesAgent < ActionAI::Agent
  end
  class HasDependenciesAgent < ActionAI::Agent
    view_cache_dependency { "trombone" }
    view_cache_dependency { "flute" }
  end

  def test_view_cache_dependencies_are_empty_by_default
    assert_empty NoDependenciesAgent.new.view_cache_dependencies
  end

  def test_view_cache_dependencies_are_listed_in_declaration_order
    assert_equal %w(trombone flute), HasDependenciesAgent.new.view_cache_dependencies
  end
end
