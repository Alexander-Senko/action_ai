# frozen_string_literal: true

require "active_job/railtie"
require "action_ai"
require "rails"
require "abstract_controller/railties/routes_helpers"

module ActionAI
  class Railtie < Rails::Railtie # :nodoc:
    config.action_ai = ActiveSupport::OrderedOptions.new
    config.action_ai.preview_paths = []
    config.eager_load_namespaces << ActionAI

    initializer "action_ai.deprecator", before: :load_environment_config do |app|
      app.deprecators[:action_ai] = ActionAI.deprecator
    end

    initializer "action_ai.logger" do
      ActiveSupport.on_load(:action_ai) { self.logger ||= Rails.logger }
    end

    initializer "action_ai.set_configs" do |app|
      paths   = app.config.paths
      options = app.config.action_ai

      options.assets_dir      ||= paths["public"].first
      options.javascripts_dir ||= paths["public/javascripts"].first
      options.stylesheets_dir ||= paths["public/stylesheets"].first
      options.show_previews = Rails.env.development? if options.show_previews.nil?
      options.cache_store ||= Rails.cache
      options.preview_paths |= ["#{Rails.root}/test/ai/previews"]

      # make sure readers methods get compiled
      options.asset_host          ||= app.config.asset_host
      options.relative_url_root   ||= app.config.relative_url_root

      ActiveSupport.on_load(:action_ai) do
        include AbstractController::UrlFor
        extend ::AbstractController::Railties::RoutesHelpers.with(app.routes, false)
        include app.routes.mounted_helpers

        self.preview_paths |= options[:preview_paths]
        self.view_paths = ["#{Rails.root}/app/ai/prompts"]

        if execution_job = options.delete(:execution_job)
          self.execution_job = execution_job.constantize
        end

        options.each { |k, v| send("#{k}=", v) }
      end

      ActiveSupport.on_load(:action_dispatch_integration_test) do
        include ActionAI::TestHelper
      end
    end

    initializer "action_ai.set_autoload_paths", before: :set_autoload_paths do |app|
      options = app.config.action_ai
      app.config.paths["test/ai/prompts/previews"].concat(options.preview_paths)
    end

    config.after_initialize do |app|
      options = app.config.action_ai

      if options.show_previews
        app.routes.prepend do
          get "/rails/ai/agents"                => "rails/ai/agents#index",    internal: true
          get "/rails/ai/agents/download/*path" => "rails/ai/agents#download", internal: true
          get "/rails/ai/agents/*path"          => "rails/ai/agents#preview",  internal: true
        end
      end
    end
  end
end
