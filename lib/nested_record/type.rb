# frozen_string_literal: true

class NestedRecord::Type < ActiveRecord::Type::Json
  require 'nested_record/type/many'
  require 'nested_record/type/one'

  def initialize(setup)
    @setup = setup
  end

  def cast(data)
    cast_value(data)
  end

  def deserialize(value)
    cast_value(super)
  end

  def serialize(obj)
    super(obj&.as_json)
  end

  private

  def record_class
    @setup.record_class
  end
end
