# frozen_string_literal: true

module Rails
  module Generators
    class AIGenerator < NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :actions, type: :array, default: [], banner: "method method"

      def create_agent_file
        template "agent.rb", File.join("app/ai/agents", class_path, "#{file_name}.rb")

        in_root do
          if behavior == :invoke && !File.exist?(application_agent_file_name)
            template "application_agent.rb", application_agent_file_name
          end
        end
      end

      hook_for :template_engine, :test_framework

      private
        def application_agent_file_name
          @_application_agent_file_name ||= if mountable_engine?
            "app/ai/agents/#{namespaced_path}/application_ai.rb"
          else
            "app/ai/agents/application_ai.rb"
          end
        end
    end
  end
end
