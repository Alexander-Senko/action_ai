# frozen_string_literal: true

class CachingAgent < ActionAI::Agent
  self.agent_name = "caching_agent"

  def fragment_cache
    ask render(template: "#{agent_name}/fragment_cache")
  end

  def fragment_cache_in_partials
    ask render(template: "#{agent_name}/fragment_cache_in_partials")
  end

  def skip_fragment_cache_digesting
    ask render(template: "#{agent_name}/skip_fragment_cache_digesting")
  end

  def fragment_caching_options
    ask render(template: "#{agent_name}/fragment_caching_options")
  end

  def multipart_cache
    ask render(template: "#{agent_name}/multipart_cache")
  end
end
