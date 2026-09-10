# frozen_string_literal: true

module ActionAI
  module ModelSchema
    # Extends schema inference with Active Record–specific behavior.
    #
    # Overrides the base inference methods to incorporate database column
    # metadata (nullability, defaults, limits, decimal scale) and model-level
    # features (defined enums, STI inheritance).
    #
    # Unlike the Active Model inference, which relies solely on validation
    # declarations, this module reads the actual column schema to produce
    # more precise constraints.
    module Inference::ActiveRecord
      def foreign_keys = reflect_on_all_associations(:belongs_to)
          .map(&:foreign_key)

      def cache_columns = [
          *(reflect_on_all_associations
              .filter_map(&:counter_cache_column)
          ),
      ]

      private

      # Excludes DB-managed columns, since they are not typically part of the
      # model’s input data.
      def schema_attributes = super
          .except(*[
              *primary_key,
              *foreign_keys.flatten,
              :created_at, :updated_at,
              locking_column,
              *cache_columns,
          ].map(&:to_sym))

      # Determines whether an attribute is required by checking the column’s
      # null constraint, in addition to any Active Model checks.
      def attribute_required? name
        super { [
          !column_for_attribute(name).null,

          *(yield if block_given?)
        ] }
      end

      # Returns the default value for an attribute from the column defaults.
      def attribute_default name
        column_defaults[name.to_s]
      end

      # Infers enum values from Active Record `enum` declarations and,
      # for the inheritance column, includes valid STI class names (the base
      # class and all descendants).
      def attribute_enum name
        super { [
          defined_enums[name],

          ([self, *descendants]
              .map(&:name) if
          name.to_s == inheritance_column),

          *(yield if block_given?)
        ] }
      end

      # Infers a constant value from acceptance validators that do not allow
      # nil, but only for non-nullable columns.
      def attribute_const name
        super { [
          *attribute_validators(name, :acceptance)
              &.select { it.options[:allow_nil] }
              .presence
              &.any?,

          *(yield if block_given?)
        ] unless column_for_attribute(name).null }
      end

      # Infers the maximum string length from the column’s database limit.
      def attribute_length name
        super { [
          {
            maximum: column_for_attribute(name).limit
          },

          *(yield if block_given?)
        ] }
      end

      # For decimal columns, sets `multiple_of` based on the column scale
      # (e.g., scale 2 → multiple_of 0.01), ensuring the generated schema
      # rejects values with more decimal places than the column supports.
      def attribute_boundaries name
        super { [
          {
            multiple_of: column_for_attribute(name)
                .then.detect { it.type == :decimal }
                &.then { 10 ** (-it.scale) },
          },

          *(yield if block_given?)
        ] }
      end
    end
  end
end
