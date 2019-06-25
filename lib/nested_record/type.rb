# frozen_string_literal: true

class NestedRecord::Type < ActiveRecord::Type::Json
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

  class HasMany < self
    private

    def collection_class
      @setup.collection_class
    end

    def cast_value(data)
      return unless data
      collection = collection_class.new
      data.each do |obj|
        if obj.is_a? Hash
          collection << record_class.instantiate(obj)
        elsif obj.kind_of?(record_class)
          collection << obj
        else
          raise "Cannot cast #{obj.inspect}"
        end
      end
      collection
    end
  end

  class HasOne < self
    private

    def cast_value(obj)
      return unless obj

      if obj.is_a? Hash
        record_class.instantiate(obj)
      elsif obj.kind_of?(record_class)
        obj
      else
        raise "Cannot cast #{obj.inspect}"
      end
    end
  end
end
