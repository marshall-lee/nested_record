# frozen_string_literal: true

class NestedRecord::Type < ActiveModel::Type::Value
  require 'nested_record/type/many'
  require 'nested_record/type/one'

  def initialize(setup)
    @setup = setup
  end

  def cast(data)
    cast_value(data)
  end

  def deserialize(value)
    value = if value.is_a?(::String)
      ActiveSupport::JSON.decode(value) rescue nil
    else
      value
    end
    cast_value(value)
  end

  def serialize(obj)
    ActiveSupport::JSON.encode(obj.as_json) unless obj.nil?
  end

  private

  def record_class
    @setup.record_class
  end
end
