class NestedRecord::Type
  class Many < self
    def deep_copy(collection)
      collection_class.new.tap do |copy|
        collection.each { |record| copy << record.dup }
      end
    end

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
end
