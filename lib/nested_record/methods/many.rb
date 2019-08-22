class NestedRecord::Methods
  class Many < self
    def initialize(setup)
      super
      define :writer
      define :rewrite_attributes
      define :upsert_attributes
      define :validation
      define_attributes_writer_method
    end

    def validation_method_name
      :"validate_associated_records_for_#{@setup.name}"
    end

    def writer_method_body
      setup = @setup
      proc do |records|
        collection_class = setup.collection_class
        return super(records.dup) if records.is_a? collection_class
        collection = collection_class.new
        records.each { |obj| collection << obj }
        super(collection)
      end
    end

    def upsert_attributes_method_body
      setup = @setup
      name = @setup.name
      proc do |data|
        attributes_collection =
          if data.is_a? Hash
            data.values
          else
            data
          end
        collection = public_send(name)
        attributes_collection.each do |attributes|
          attributes = attributes.stringify_keys
          next if setup.reject_if_proc&.call(attributes)

          if (pkey_attributes = setup.primary_key)
            klass = setup.record_class
          else
            klass = setup.record_class.find_subtype(attributes['type'])
            while !(pkey_attributes = klass.primary_key) && (klass < NestedRecord::Base)
              klass = klass.superclass
            end
            unless pkey_attributes
              raise NestedRecord::ConfigurationError, 'You should specify a primary_key when using :upsert strategy'
            end
          end
          key = { _is_a?: klass }
          pkey_attributes.each do |name|
            value = attributes[name]
            if (type = klass.type_for_attribute(name))
              value = type.cast(value)
            end
            key[name] = value
          end
          if (record = collection.find_by(key))
            record.assign_attributes(attributes)
          else
            collection.build(attributes)
          end
        end
      end
    end

    def rewrite_attributes_method_body
      setup = @setup
      writer_method_name = self.writer_method_name
      proc do |data|
        attributes_collection =
          if data.is_a? Hash
            data.values
          else
            data
          end
        collection = setup.collection_class.new
        attributes_collection.each do |attributes|
          attributes = attributes.stringify_keys
          next if setup.reject_if_proc&.call(attributes)
          collection.build(attributes)
        end
        public_send(writer_method_name, collection)
      end
    end

    def validation_method_body
      name = @setup.name
      proc do
        collection = public_send(name)
        collection.map.with_index do |record, index|
          next true if record.valid?
          record.errors.each do |attribute, message|
            error_attribute = "#{name}[#{index}].#{attribute}"
            errors[error_attribute] << message
            errors[error_attribute].uniq!
          end
          record.errors.details.each_key do |attribute|
            error_attribute = "#{name}[#{index}].#{attribute}"
            record.errors.details[attribute].each do |error|
              errors.details[error_attribute] << error
              errors.details[error_attribute].uniq!
            end
          end
          false
        end.all?
      end
    end
  end
end
