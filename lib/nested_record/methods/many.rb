class NestedRecord::Methods
  class Many < self
    def initialize(setup)
      super
      define :reader
      define :writer
      define :rewrite_attributes
      define :upsert_attributes
      define :validation
      define_attributes_writer_method
    end

    def validation_method_name
      :"validate_associated_records_for_#{@setup.name}"
    end

    def reader_method_body
      setup = @setup
      ivar = :"@_#{@setup.name}_collection_proxy"
      proc do
        instance_variable_get(ivar) || instance_variable_set(ivar, setup.collection_proxy_class.new(self))
      end
    end

    def writer_method_body
      setup = @setup
      proc do |records|
        collection_class = setup.collection_class
        if records.is_a? collection_class
          collection = records.dup
        else
          collection = collection_class.new
          records.each { |record| collection << record }
        end
        collection.group_by { |record| setup.primary_check(record.read_attribute('type')) }.each do |check, records|
          next unless check
          records.each do |record|
            check.perform!(collection, record)
          end
        end
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

          pkey_check = setup.primary_check(attributes['type'])
          unless pkey_check
            raise NestedRecord::ConfigurationError, 'You should specify a primary_key when using :upsert strategy'
          end

          pkey = pkey_check.build_pkey(attributes)

          if (record = collection.find_by(pkey))
            record.assign_attributes(attributes)
          else
            collection.__build__(attributes)
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
