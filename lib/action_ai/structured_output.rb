# frozen_string_literal: true

module ActionAI
  module StructuredOutput
    def ask(*, as: @model_class, **, &)
      super(*, **, &)&.tap do |message|
        model_class = as or next

        object = message.parsed&.then do |params|
          case model_class
          when Array
            params.map { model_class.sole.new it }
          else
            model_class.new params
          end
        end

        message.define_singleton_method(:object) { object }
      end
    end

    # Declares the structured return type for this action. Configures the chat
    # to request output matching the model's schema, and decorates the resulting
    # +RubyLLM::Message+ with +#object+ accessor.
    #
    # Call +returns+ inside an action method before +ask+ (or before the
    # implicit ask) to indicate which ActiveModel class the LLM should fill in:
    #
    #   class Extractor < ApplicationAI
    #     def person(text)
    #       @text = text
    #       returns Person
    #     end
    #   end
    #
    # After execution:
    #
    #   response = Extractor.person("Alice is 30 years old")
    #   response.content # => '{"name":"Alice","age":30}'
    #   response.parsed  # => {"name" => "Alice", "age" => 30}
    #   response.object  # => #<Person name="Alice" age=30>
    #
    # Pass an array with a single element to declare an array return type:
    #
    #   class Extractor < ApplicationAI
    #     def people(text)
    #       @text = text
    #       returns [Person]
    #     end
    #   end
    #
    # After execution:
    #
    #   response = Extractor.people("Alice is 30 and Bob is 25")
    #   response.content # => '[{"name":"Alice","age":30},{"name":"Bob","age":25}]'
    #   response.parsed  # => [{"name" => "Alice", "age" => 30}, {"name" => "Bob", "age" => 25}]
    #   response.object  # => [#<Person name="Alice" age=30>, #<Person name="Bob" age=25>]
    #
    # The +model_class+ must respond to +.schema+, which is automatically
    # available on any model that includes +ActiveModel::Attributes+.
    def returns model_class
      chat.with_schema case @model_class = model_class
      when Array
        { type: "array", items: model_class.sole.to_json_schema }
      else
        model_class.schema
      end
    end
  end
end
