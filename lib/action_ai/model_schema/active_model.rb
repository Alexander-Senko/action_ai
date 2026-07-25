# frozen_string_literal: true

require "active_support/concern"
require "action_ai/refinements/regexp"

module ActionAI
  module ModelSchema
    # Extends schema inference with Active Model–specific behavior.
    #
    # Overrides the base inference methods to extract constraint metadata
    # from Active Model validation declarations (presence, inclusion,
    # numericality, format, length, comparison, and acceptance).
    module ActiveModel
      extend ActiveSupport::Concern

      class_methods do
        using Refinements::Regexp

        private

        # Determines whether an attribute is required by checking for
        # a presence validator, in addition to any other sources.
        def attribute_required? name
          super { [
            attribute_validators(name, :presence)
                .any?,

            *(yield if block_given?)
          ] }
        end

        # Infers enum values from inclusion and numericality validators
        # that declare an `:in` option with multiple values.
        def attribute_enum name
          super { [
            *[
              *attribute_validators(name, :numericality),
              *attribute_validators(name, :inclusion),
            ].filter_map { it.options[:in] },

            *(yield if block_given?)
          ] }
        end

        # Infers a constant value from validators that restrict the
        # attribute to a single value: comparison/equality, single-item
        # inclusion, or acceptance validators without `allow_nil`.
        def attribute_const name
          super { [
            *[
              *attribute_validators(name, :comparison),
              *attribute_validators(name, :numericality),
            ].filter_map { it.options[:equal_to] },

            *[
              *attribute_validators(name, :inclusion),
              *attribute_validators(name, :numericality),
            ].filter_map { it.options[:in] }
                .select(&:one?)
                .map(&:first),

            *attribute_validators(name, :acceptance)
                .reject { it.options[:allow_nil] }
                .presence
                &.any?,

            *(yield if block_given?)
          ] }
        end

        # Infers a regex pattern from format validators, combining
        # multiple patterns into a single expression.
        # Validators with `:without` are negated.
        def attribute_format name
          super { [
            *attribute_validators(name, :format)
                .map(&:options)
                .filter_map { it[:with] or ~it[:without] rescue nil },

            *(yield if block_given?)
          ] }
        end

        # Infers minimum and maximum string length from length validators.
        def attribute_length name
          super { [
            *attribute_validators(name, :length)
                .map(&:options)
                .map { {
                  minimum: it.values_at(:is, :minimum).find(&:itself),
                  maximum: it.values_at(:is, :maximum).find(&:itself),
                } },

            *(yield if block_given?)
          ] }
        end

        # Infers numeric boundaries (minimum, maximum, greater_than,
        # less_than, multiple_of) from comparison and numericality validators.
        def attribute_boundaries name
          super { [
            *[
              *attribute_validators(name, :comparison),
              *attribute_validators(name, :numericality),
            ].map(&:options)
                .map { {
                  minimum:      it[:greater_than_or_equal_to],
                  greater_than: it[:greater_than],
                  less_than:    it[:less_than],
                  maximum:      it[:less_than_or_equal_to],

                  multiple_of:  it[:multiple_of],
                } },

            *(yield if block_given?)
          ] }
        end

        # Returns the validators for an attribute, optionally filtered
        # by validator type (e.g., `:presence`, `:inclusion`, `:format`).
        def attribute_validators name, type = nil
          validators_on(name)
              .grep(::ActiveModel::Validations.const_get "#{type.to_s.camelize}Validator")
        end
      end
    end
  end
end
