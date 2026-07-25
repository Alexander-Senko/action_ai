# frozen_string_literal: true

module ActionAI
  module Refinements
    module Regexp
      refine ::Regexp do
        def ~@
          self.class.new "\\A(?:(?!#{source}).)*\\z", options
        end
      end
    end
  end
end
