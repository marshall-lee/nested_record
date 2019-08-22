class NestedRecord::Methods
  class One < self
    def initialize(setup)
      super
      define :writer
      define :build
      alias_method rewrite_attributes_method_name, build_method_name
      define :bang
      define :upsert_attributes
      define :validation
      define_attributes_writer_method
    end

    def writer_method_body
      setup = @setup
      proc do |record|
        unless record.nil? || record.kind_of?(setup.record_class)
          raise NestedRecord::TypeMismatchError, "#{record.inspect} should be a #{setup.record_class}"
        end
        super(record)
      end
    end

    def build_method_name
      :"build_#{@setup.name}"
    end

    def build_method_body
      setup = @setup
      writer_method_name = self.writer_method_name
      proc do |attributes = {}|
        record = setup.record_class.new(attributes)
        public_send(writer_method_name, record)
      end
    end

    def bang_method_name
      :"#{@setup.name}!"
    end

    def bang_method_body
      <<~RUBY
        #{@setup.name} || #{build_method_name}
      RUBY
    end

    def upsert_attributes_method_body
      build_method_name = self.build_method_name
      name = @setup.name
      proc do |attributes|
        if (record = public_send(name))
          record.assign_attributes(attributes)
        else
          public_send(build_method_name, attributes)
        end
      end
    end

    def validation_method_name
      :"validate_associated_record_for_#{@setup.name}"
    end

    def validation_method_body
      name = @setup.name
      proc do
        record = public_send(name)
        return true unless record
        return true if record.valid?

        record.errors.each do |attribute, message|
          error_attribute = "#{name}.#{attribute}"
          errors[error_attribute] << message
          errors[error_attribute].uniq!
        end
        record.errors.details.each_key do |attribute|
          error_attribute = "#{name}.#{attribute}"
          record.errors.details[attribute].each do |error|
            errors.details[error_attribute] << error
            errors.details[error_attribute].uniq!
          end
        end
        false
      end
    end
  end
end
