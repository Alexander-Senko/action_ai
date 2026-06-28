# frozen_string_literal: true

module RubyLLM
  module Providers
    # Echo model behavior for the RubyLLM Test provider.
    #
    # A deterministic response builder (`#echo_response`) returns
    # incoming prompt content.
    #
    # It is intended to be mixed into `RubyLLM::Providers::Test`.
    module Test::Echo
      def self.id = "echo"

      def self.info = Model::Info.new(
        id:,
        name:,
        provider:     Test.slug,
        capabilities: Test.capabilities,

        modalities: {
          input:  %w[text],
          output: %w[text],
        },
      )

      private

      def echo_response(messages, **) = {
        content: RubyLLM.concat_content(messages
                     .reverse_each.take_while { it.role != :assistant }.reverse
                     .map(&:content)
                 ),
      }
    end
  end

  def self.concat_content *parts
    strings, contents = parts
        .flatten
        .partition { it.is_a? String }

    Content.new(
      [*strings, *contents.map(&:text)]
          .reject(&:empty?)
          .join("\n\n"),
      contents.sum([], &:attachments)
          .map(&:source)
    )
  end
end
