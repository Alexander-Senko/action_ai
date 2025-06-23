# frozen_string_literal: true

require 'ruby_llm'

module RubyLLM
  configure do
    it.default_model = "echo"
  end

  Provider.register :test, Module.new {
    extend Provider

    module_function

    def api_base(...) = "https://echo.free.beeceptor.com/"

    def capabilities = Module.new do
    end

    def slug = "test"

    def configuration_requirements = []

    def list_models(...) = [
      Model::Info.new(
        id: "echo",
        provider: slug,
      ),
    ]

    def render_payload(messages, tools:, temperature:, model:, stream: false)
      {
        model:,
        messages: messages.map(&:to_h),
        options: {
          temperature:
        },
      }
    end

    def completion_url = ""

    def parse_completion_response(response)
      data = response.body["parsedBody"]

      Message.new(
        role:     :assistant,
        content:  data.dig("messages", -1, "content"),
        model_id: data["model"]
      )
    end
  }

  Models.refresh!
end
