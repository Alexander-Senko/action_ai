# frozen_string_literal: true

require "active_support/descendants_tracker"

module ActionAI
  module Previews # :nodoc:
    extend ActiveSupport::Concern

    included do
      # Add the location of AI agent previews through app configuration:
      #
      #     config.action_ai.preview_paths << "#{Rails.root}/lib/ai/previews"
      #
      mattr_accessor :preview_paths, instance_writer: false, default: []

      # Enable or disable prompt previews through app configuration:
      #
      #     config.action_ai.show_previews = true
      #
      # Defaults to +true+ for development environment
      #
      mattr_accessor :show_previews, instance_writer: false
    end
  end

  class Preview
    extend ActiveSupport::DescendantsTracker

    attr_reader :params

    def initialize(params = {})
      @params = params
    end

    class << self
      # Returns all agent preview classes.
      def all
        load_previews if descendants.empty?
        descendants.sort_by { it.name.titleize }
      end

      # Returns the message object for the given action name.
      def call(action, params = {})
        preview = new(params)
        message = preview.public_send(action)
        message
      end

      # Returns all of the available action previews.
      def actions
        public_instance_methods(false).map(&:to_s).sort
      end

      # Returns +true+ if the action exists.
      def action_exists?(action)
        actions.include?(action)
      end

      # Returns +true+ if the preview exists.
      def exists?(preview)
        all.any? { |p| p.preview_name == preview }
      end

      # Find an agent preview by its underscored class name.
      def find(preview)
        all.find { |p| p.preview_name == preview }
      end

      # Returns the underscored name of the agent preview without the suffix.
      def preview_name
        name.delete_suffix("Preview").underscore
      end

      private
        def load_previews
          preview_paths.each do |preview_path|
            Dir["#{preview_path}/**/*_preview.rb"].sort.each { |file| require file }
          end
        end

        def preview_paths
          Agent.preview_paths
        end

        def show_previews
          Agent.show_previews
        end
    end
  end
end
