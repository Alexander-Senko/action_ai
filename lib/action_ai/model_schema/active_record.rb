# frozen_string_literal: true

require "active_support/concern"

module ActionAI::ModelSchema
  module ActiveRecord
    extend ActiveSupport::Concern

    class_methods do
      private

      def attribute_required? name
        super { [
          !column_for_attribute(name).null,

          *(yield if block_given?)
        ] }
      end

      def attribute_default name
        column_defaults[name.to_s]
      end

      def attribute_enum name
        super { [
          defined_enums[name],

          *(yield if block_given?)
        ] }
      end

      def attribute_const name
        super { [
          *attribute_validators(name, :acceptance)
              &.select { it.options[:allow_nil] }
              .presence
              &.any?,

          *(yield if block_given?)
        ] unless column_for_attribute(name).null }
      end

      def attribute_length name
        super { [
          {
            maximum: column_for_attribute(name).limit
          },

          *(yield if block_given?)
        ] unless column_for_attribute(name).null }
      end

      def attribute_boundaries name
        super { [
          {
            multiple_of: column_for_attribute(name)
                .then.select { it.type == :decimal }.first
                &.then { 10 ** (-it.scale) },
          },

          *(yield if block_given?)
        ] }
      end
    end
  end
end
