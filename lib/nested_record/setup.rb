# frozen_string_literal: true

class NestedRecord::Setup
  def initialize(owner, name, **options, &extension)
    @options = options
    @owner = owner
    @record_class = options[:class_name] || name.to_s.classify
    @name = name
    @extension = extension

    define_methods

    @owner.attribute @name, type, default: default_value
    @owner.validate validation_method_name
  end

  def record_class
    if @record_class.is_a? String
      @record_class = NestedRecord.lookup_const(@owner, @record_class)
    end
    @record_class
  end

  private

  def writer_method_name
    @writer_method_name ||= :"#{@name}="
  end

  def attributes_writer_method_name
    @attributes_writer_method_name ||= :"#{@name}_attributes="
  end

  def validation_method_name
    @validation_method_name ||= :"validate_associated_records_for_#{@name}"
  end

  def define_methods
    define_writer_method
    define_attributes_writer_method
    define_validation_method
  end

  class HasMany < self
    def initialize(*)
      super
      if (attributes_writer_opts = @options[:attributes_writer]).is_a? Hash
        @reject_if_proc = attributes_writer_opts[:reject_if]
      end
    end

    def type
      @type ||= NestedRecord::Type::HasMany.new(self)
    end

    def collection_class_name
      @collection_class_name ||= :"NestedRecord_Many#{@name.to_s.camelize}"
    end

    def collection_class
      return @owner.const_get(collection_class_name, false) if @owner.const_defined?(collection_class_name, false)
      extension = @extension
      collection_superclass = record_class.collection_class
      @owner.const_set(
        collection_class_name,
        Class.new(collection_superclass) do
          @record_class = collection_superclass.record_class
          include Module.new(&extension) if extension
        end
      )
    end

    def reject?(attributes)
      @reject_if_proc&.call(attributes)
    end

    private

    def default_value
      []
    end

    def define_writer_method
      setup = self
      @owner.define_method(writer_method_name) do |records|
        collection_class = setup.collection_class
        return super(records.dup) if records.is_a? collection_class
        collection = collection_class.new
        records.each do |obj|
          collection << obj
        end
        super(collection)
      end
    end

    def define_attributes_writer_method
      return unless @options.fetch(:attributes_writer) { true }
      setup = self
      writer_method = writer_method_name
      @owner.define_method(attributes_writer_method_name) do |data|
        attributes_collection =
          if data.is_a? Hash
            data.values
          else
            data
          end
        collection = setup.collection_class.new
        attributes_collection.each do |attributes|
          attributes = attributes.stringify_keys
          next if setup.reject?(attributes)
          collection.build(attributes)
        end
        public_send(writer_method, collection)
      end
    end

    def define_validation_method
      setup = self
      name = @name
      @owner.define_method(validation_method_name) do
        collection = public_send(name)
        collection.map do |record|
          next true if record.valid?
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
        end.all?
      end
    end
  end

  class HasOne < self
    def define_methods
      define_writer_method
      define_build_method
      define_attributes_writer_method
      define_validation_method
      define_bang_method
    end

    def type
      @type ||= NestedRecord::Type::HasOne.new(self)
    end

    private

    def default_value
      nil
    end

    def build_method_name
      :"build_#{@name}"
    end

    def bang_method_name
      :"#{@name}!"
    end

    def define_writer_method
      setup = self
      @owner.define_method(writer_method_name) do |record|
        unless record.nil? || record.kind_of?(setup.record_class)
          raise NestedRecord::TypeMismatchError, "#{record.inspect} should be a #{setup.record_class}"
        end
        super(record)
      end
    end

    def define_attributes_writer_method
      return unless @options.fetch(:attributes_writer) { true }
      @owner.alias_method attributes_writer_method_name, build_method_name
    end

    def define_validation_method
      setup = self
      name = @name
      @owner.define_method(validation_method_name) do
        record = public_send(name)
        return true unless record
        return true if record.valid?

        record.errors.each do |attribute, message|
          error_attribute = "#{name}.#{attribute}"
          errors.details[error_attribute] << message
          errors.details[error_attribute].uniq!
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

    def define_build_method
      setup = self
      writer_method = writer_method_name
      @owner.define_method(build_method_name) do |attributes = {}|
        record = setup.record_class.new(attributes)
        public_send(writer_method, record)
      end
    end

    def define_bang_method
      @owner.class_eval <<~RUBY
        def #{bang_method_name}
          #{@name} || #{build_method_name}
        end
      RUBY
    end
  end
end
