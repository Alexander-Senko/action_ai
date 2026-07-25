# frozen_string_literal: true

module ActionAI
  module Refinements
    module Numeric
      refine ::Numeric do
        def lcm other
          m = [ self, other ]
              .grep_v(Integer)
              .map(&:rationalize)
              .map(&:denominator)
              .reduce(&:*)

          [ self, other ]
              .map { it * m }
              .map(&:to_i)
              .reduce(&:lcm)
              .send(other.is_a?(Integer) ? :/ : :fdiv, m)
        end
      end

      refine ::Integer do
        def lcm other
          return other.lcm self unless
              other.is_a? Integer

          super
        end
      end
    end
  end
end
