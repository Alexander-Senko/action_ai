# frozen_string_literal: true

require "schematist"
require "active_support/concern"
require "action_ai/refinements/numeric"

module ActionAI
  # = Action AI Model Schema
  #
  # Adds a +.schema+ class method to any model that includes
  # +ActiveModel::AttributeRegistration+. The returned schema is a
  # +Schematist::Schema+ instance derived from the model's attribute types,
  # suitable for use with +RubyLLM::Chat#with_schema+ and
  # +ActionAI::Agent#returns+.
  #
  # Inject this module once (e.g. via the Railtie) and every ActiveModel class
  # defined afterwards will gain +.schema+ automatically:
  #
  #   ActiveModel::API.include ActionAI::ModelSchema
  #
  # == Type mapping
  #
  # ActiveModel attribute types are mapped to JSON Schema types as follows:
  #
  # * +:string+, +:immutable_string+, +:text+ → +string+
  # * +:integer+, +:big_integer+ → +integer+
  # * +:float+, +:decimal+, +:big_decimal+ → +number+
  # * +:boolean+ → +boolean+
  # * +:binary+ → +string+ with +contentEncoding: "base64"+
  # * +:date+, +:datetime+, +:time+ → +string+ with the corresponding
  #   JSON Schema +format+
  #
  # Other types are omitted from the schema.
  module ModelSchema
    extend ActiveSupport::Concern
    extend Schematist::Helpers

    autoload :ActiveModel,  "action_ai/model_schema/active_model"
    autoload :ActiveRecord, "action_ai/model_schema/active_record"

    TYPES = {
      string:           :string,
      immutable_string: :string,
      text:             :string,
      integer:          :integer,
      big_integer:      :integer,
      float:            :number,
      decimal:          :number,
      big_decimal:      :number,
      boolean:          :boolean,
      date:             :string,
      datetime:         :string,
      time:             :string,
      binary:           :string,
    }.freeze

    FORMATS = {
      date:     "date",
      datetime: "date-time",
      time:     "time",
    }.freeze

    ENCODINGS = {
      binary: "base64",
    }.freeze

    def self.included base
      super
      
      base.include ActiveModel  if defined? ::ActiveModel  and base <= ::ActiveModel::API
      base.include ActiveRecord if defined? ::ActiveRecord and base <= ::ActiveRecord::Base
    end

    def self.new(...) = schema(...)

    class_methods do
      include Memery
      using   ActionAI::Refinements::Numeric

      # Returns a cached +Schematist::Schema+ instance derived from this
      # model's attribute types.
      #
      # Numeric constraints and enum-like metadata are inferred from model
      # validations when Rails exposes them, even when the validator itself is
      # not actively enforced. In particular, +multiple_of+ is accepted by the
      # schema generator here for JSON Schema output, even though
      # +ActiveModel::Validations::NumericalityValidator+ ignores it at runtime.
      memoize def schema = build_schema

      def build_schema
        attributes = schema_attributes

        ModelSchema.new schema_name, **{
          description: try(:model_name)&.human,
        } do
          attributes.each do |name, options|
            send options.delete(:type), name, **options
          end
        end
      end

      memoize def to_json_schema = schema.to_json_schema
        .with_indifferent_access

      private

      def schema_name = "#{name}Schema"

      memoize def schema_attributes = attribute_types
          .symbolize_keys
          .transform_values(&:type)
          .filter_map { |name, type|
            [ name, {
              type:             (TYPES[type] or next),
              format:           FORMATS[type],
              content_encoding: ENCODINGS[type],
              description:      try(:human_attribute_name, name),
              required:         attribute_required?(name),
              default:          attribute_default(name),
              enum:             attribute_enum(name),
              const:            attribute_const(name),
              pattern:          attribute_format(name),

              **attribute_length(name),
              **attribute_boundaries(name),
            }.compact! ]
          }
          .to_h

      def attribute_types = raise NotImplementedError

      def attribute_required?(name) = [
        *(yield if block_given?)
      ].any?

      def attribute_default(name) = default_instance.send name

      def attribute_enum(name) = [
        *(yield if block_given?)
      ].compact.presence
          &.map(&:to_a)
          &.inject(&:&)
          &.then&.select(&:many?)&.first

      def attribute_const(name) = [
        *(yield if block_given?)
      ].compact.presence
          &.uniq
          &.sole

      def attribute_format(name) = [
        *(yield if block_given?)
      ].compact.presence
          &.then { return it.first if it.one? }
          &.map { "(?=.*#{it})" }
          &.join
          &.then { Regexp.new "\\A#{it}" }

      def attribute_length(name) = [
        *(yield if block_given?)
      ].map { it.values_at :minimum, :maximum }
          .transpose
          .map(&:compact)
          .map(&:presence)
          .then do |(minimums, maximums)|
            {
              min_length: minimums&.max,
              max_length: maximums&.min,
            }
          end

      def attribute_boundaries(name) = [
        *(yield if block_given?)
      ].map { it.values_at :minimum, :maximum, :greater_than, :less_than, :multiple_of }
          .transpose
          .map(&:compact)
          .map(&:presence)
          .then do |(minimums, maximums, lowers, uppers, multiples)|
            {
              minimum:      minimums&.max,
              maximum:      maximums&.min,
              greater_than: lowers&.max,
              less_than:    uppers&.min,
              multiple_of:  multiples&.reduce(&:lcm),
            }
          end

      memoize def default_instance = new
    end
  end
end
