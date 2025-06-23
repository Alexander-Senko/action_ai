# frozen_string_literal: true

module ActionAI
  module Callbacks
    extend ActiveSupport::Concern

    included do
      include ActiveSupport::Callbacks
      define_callbacks :execution, skip_after_callbacks_if_terminated: true
    end

    module ClassMethods
      # Defines a callback that will get called right before the
      # prompt is sent to the execution method.
      def before_execution(*filters, &blk)
        set_callback(:execution, :before, *filters, &blk)
      end

      # Defines a callback that will get called right after the
      # prompt's execution method is finished.
      def after_execution(*filters, &blk)
        set_callback(:execution, :after, *filters, &blk)
      end

      # Defines a callback that will get called around the prompts's execution method.
      def around_execution(*filters, &blk)
        set_callback(:execution, :around, *filters, &blk)
      end
    end
  end
end
