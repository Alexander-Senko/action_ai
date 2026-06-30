# frozen_string_literal: true

require "ruby_llm"

module RubyLLM
  module Protocols
    # An in-memory protocol that returns the current prompt as the response.
    class Echo < Protocol
      def complete(messages, **)
        Message.new(
          role: :assistant,
          model: model.id,

          content: messages
            .reverse_each.take_while { it.role != :assistant }.reverse
            .map(&:content)
            .reject(&:blank?)
            .join("\n\n"),

          attachments: messages
            .sum([], &:attachments),
        ).tap { yield it if block_given? }
      end
    end
  end
end
