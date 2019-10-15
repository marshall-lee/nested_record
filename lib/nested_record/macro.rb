# frozen_string_literal: true

module NestedRecord::Macro
  extend ActiveSupport::Concern

  module ClassMethods
    def has_many_nested(name, **options, &block)
      NestedRecord::Setup::HasMany.new(self, name, **options, &block)
    end

    def has_one_nested(name, **options, &block)
      NestedRecord::Setup::HasOne.new(self, name, **options, &block)
    end

    def nested_accessors(from:, **options, &block)
      NestedRecord::NestedAccessorsSetup.new(self, from, **options, &block)
    end
  end
end
