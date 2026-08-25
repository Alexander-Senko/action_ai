# frozen_string_literal: true

require "schematist"
require "magic/lookup"

module ActionAI
  class Schema < Schematist::Schema
    extend Magic::Lookup

    class << self
      def name_for object_class
        object_class
          .to_s
          .delete_suffix('Model')
          .delete_suffix('Record')
          .concat('Schema')
      end
    end
  end
end
