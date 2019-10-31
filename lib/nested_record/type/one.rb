class NestedRecord::Type
  class One < self
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
