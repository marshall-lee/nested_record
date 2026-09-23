# frozen_string_literal: true

module NestedRecord::Macro
  extend ActiveSupport::Concern

  # ActiveModel shares a nested value between the copies when it was not
  # read before dup. Give the copy its own records.
  def initialize_dup(other)
    super
    self.class.attribute_types.each do |name, type|
      next unless type.is_a?(NestedRecord::Type)

      value = public_send(name)
      public_send(:"#{name}=", type.deep_copy(value)) unless value.nil?
    end
  end

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
