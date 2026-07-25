# frozen_string_literal: true

require "abstract_unit"
require "action_ai/refinements/numeric"
require "action_ai/refinements/regexp"

module UnrefinedCoreMethods
  def self.regexp_unary_source_location
    Regexp.instance_method(:~@).source_location
  end

  def self.numeric_lcm_defined?
    Numeric.method_defined? :lcm
  end
end

class RefinementsTest < ActiveSupport::TestCase
  using ActionAI::Refinements::Numeric
  using ActionAI::Refinements::Regexp

  test "Regexp refinement builds a negative matching regexp" do
    regexp = ~/forbidden/

    assert     regexp.match? "allowed"
    assert     regexp.match? ""
    assert     regexp.match? "FORBIDDEN"
    assert_not regexp.match? "forbidden"
    assert_not regexp.match? "allowed and forbidden"
  end

  test "Regexp refinement preserves regexp options" do
    regexp = ~/forbidden/im

    assert_equal Regexp::IGNORECASE | Regexp::MULTILINE, regexp.options
    assert_not regexp.match? "FORBIDDEN"
    assert_not regexp.match? "forbidden"
  end

  test "Numeric refinement calculates least common multiples with decimals" do
    assert_equal 0.5, 0.5.lcm(0.25)
    assert_equal 2.0, 0.5.lcm(2)
    assert_equal 2.0,   2.lcm(0.5)
    assert_equal 0.5, 0.5.lcm(0.5)
  end

  test "Numeric refinement handles zero and negative decimal values" do
    assert_equal 0.0,    0.5.lcm(0)
    assert_equal 0.5, (-0.5).lcm(0.25)
  end

  test "Integer refinement preserves native integer lcm" do
    assert_equal 12, 6.lcm(4)
    assert_equal 6,  6.lcm(-3)
  end

  test "refinements do not modify core classes globally" do
    assert_nil UnrefinedCoreMethods.regexp_unary_source_location
    assert_not UnrefinedCoreMethods.numeric_lcm_defined?
  end
end
