# frozen_string_literal: true

class NestedRecord::Base
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Dirty
  include NestedRecord::Macro

  class << self
    def attributes_builder # :nodoc:
      unless defined?(@attributes_builder) && @attributes_builder
        @attributes_builder = ActiveModel::AttributeSet::Builder.new(attribute_types, _default_attributes)
      end
      @attributes_builder
    end

    def inherited(klass)
      if self < NestedRecord::Base
        klass.class_eval do
          attribute :type, :string
          @deep_inherted = true
        end
      end
      super
    end

    def deep_inherited?
      @deep_inherted == true
    end

    def new(attributes = nil)
      if attributes
        attributes = attributes.stringify_keys
        klass = find_instance_class(attributes['type'])
      else
        klass = self
      end
      if self == klass
        super(attributes)
      else
        klass.new(attributes)
      end
    end

    def instantiate(attributes)
      klass = find_instance_class(attributes['type'])
      attributes = klass.attributes_builder.build_from_database(attributes)
      klass.allocate.tap do |instance|
        instance.instance_variable_set(:@attributes, attributes)
      end
    end

    def collection_class_name
      :NestedRecord_Collection
    end

    def collection_class
      return const_get(collection_class_name, false) if const_defined?(collection_class_name, false)
      record_class = self
      collection_superclass = deep_inherited? ? superclass.collection_class : NestedRecord::Collection
      const_set(
        collection_class_name,
        Class.new(collection_superclass) do
          @record_class = record_class
        end
      )
    end

    def collection_methods(&block)
      collection_class.class_eval(&block)
    end

    def inherited_types(options)
      raise ArgumentError, '.inherited_types is supported only for base classes' if deep_inherited?
      if options[:full] && options[:namespace]
        raise ArgumentError, ':full and :namespace options cannot be used at the same time'
      end
      @inherited_types_options = options
    end

    def instance_type
      @instance_type ||=
        if inherited_types_underscored?
          type_const.underscore
        else
          type_const.dup
        end
    end

    protected

    def inherited_types_options
      @inherited_types_options ||= {}
      if deep_inherited?
        superclass.inherited_types_options.merge(@inherited_types_options)
      else
        @inherited_types_options
      end
    end

    private

    def type_const
      if inherited_types_namespace
        name.gsub(/\A#{inherited_types_namespace}::/, '')
      else
        name
      end
    end

    def inherited_types_store_full?
      !inherited_types_namespace && inherited_types_options.fetch(:full) { true }
    end

    def inherited_types_namespace
      return @inherited_types_namespace if defined?(@inherited_types_namespace)

      namespace = inherited_types_options.fetch(:namespace) { false }
      return (@inherited_types_namespace = false) unless namespace

      @inherited_types_namespace = NestedRecord.lookup_const(self, namespace).name
    end

    def inherited_types_underscored?
      inherited_types_options.fetch(:underscored) { false }
    end

    def find_instance_class(type_name)
      return self unless type_name.present?

      type_name = type_name.camelize

      subclass =
        begin
          if type_name.start_with?('::')
            ActiveSupport::Dependencies.constantize(type_name)
          elsif inherited_types_store_full?
            ActiveSupport::Dependencies.constantize(type_name)
          elsif inherited_types_namespace
            ActiveSupport::Dependencies.safe_constantize("#{inherited_types_namespace}::#{type_name}") || ActiveSupport::Dependencies.constantize(type_name)

          else
            NestedRecord.lookup_const(self, type_name)
          end
        rescue NameError
          raise NestedRecord::InvalidTypeError, "Failed to locate type '#{type_name}'"
        end
      unless subclass.is_a? Class
        raise NestedRecord::InvalidTypeError, "Invalid type '#{type_name}': should be a class"
      end
      unless subclass <= self
        raise NestedRecord::InvalidTypeError, "Invalid type '#{type_name}': should be a subclass of #{self}"
      end
      subclass
    end
  end

  def initialize(attributes = nil)
    super
    self.type = self.class.instance_type if self.class.deep_inherited?
  end

  def ==(other)
    attributes == other.attributes
  end

  def as_json
    attributes.transform_values(&:as_json)
  end

  def inspect
    as = attributes.except('type').map { |k,v| "#{k}: #{v.inspect}" }
    "#<#{self.class.name} #{as.join(', ')}>"
  end

  def read_attribute(attr)
    @attributes.fetch_value(attr.to_s)
  end

  def match?(attrs)
    attrs.all? do |attr, others|
      ours = read_attribute(attr)
      if others.is_a? Array
        others.include? ours
      else
        others == ours
      end
    end
  end
end
