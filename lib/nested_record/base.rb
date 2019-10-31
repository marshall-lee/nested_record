# frozen_string_literal: true

class NestedRecord::Base
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Dirty
  include ActiveModel::Validations::Callbacks
  include NestedRecord::Macro

  class << self
    include ActiveModel::Callbacks

    def attributes_builder # :nodoc:
      unless defined?(@attributes_builder) && @attributes_builder
        @attributes_builder = ActiveModel::AttributeSet::Builder.new(attribute_types, _default_attributes)
      end
      @attributes_builder
    end

    def inherited(klass)
      parent = self
      if parent < NestedRecord::Base
        klass.class_eval do
          attribute :type, :string unless parent.has_attribute? :type
          @deep_inherted = true
        end
      end
      super
    end

    def deep_inherited?
      @deep_inherted == true
    end

    def new(attributes = nil)
      if local_subtype?
        return super
      else
        if attributes
          attributes = attributes.stringify_keys
          klass = find_subtype(attributes['type'])
        else
          klass = self
        end
      end
      if self == klass
        super
      else
        klass.new(attributes)
      end
    end

    def instantiate(attributes)
      klass = find_subtype(attributes['type'])
      attributes = klass.attributes_builder.build_from_database(attributes)
      klass.allocate.tap do |instance|
        instance.init_with_attributes(attributes)
      end
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
      raise ArgumentError, 'block is required for .collection_methods' unless block
      collection_class.class_eval(&block)
    end

    def subtypes(options)
      raise NestedRecord::ConfigurationError, '.subtypes is supported only for base classes' if deep_inherited?
      if options[:full] && options[:namespace]
        raise NestedRecord::ConfigurationError, ':full and :namespace options cannot be used together'
      end
      @subtypes_options = options
    end

    def instance_type
      @instance_type ||=
        if subtypes_underscored?
          type_const.underscore
        else
          type_const.dup
        end
    end

    def subtype(name, &block)
      raise NotImplementedError, 'TODO: Subtyping from local subtype is not supported at the moment' if local_subtype?
      class_name = name.to_s.camelize
      subtype = Class.new(self) do
        @local_subtype = true
        @type_const = class_name
        class_eval(&block) if block
      end
      local_subtypes!.const_set(class_name, subtype)
    end

    def attribute(name, *args, primary: false, **options)
      super(name, *args, **options).tap do
        primary_key(name) if primary
      end
    end

    def primary_key(*attributes)
      unless attributes.empty?
        self.primary_key = attributes
      end
      @primary_key
    end

    def def_primary_uuid(name)
      attribute name, :string, default: -> { SecureRandom.uuid }, primary: true
    end

    def primary_key=(attributes)
      attributes = Array(attributes)
      raise ArgumentError, 'primary_key cannot be an empty array' if attributes.empty?
      @primary_key = attributes.map(&:to_s)
    end

    def type_for_attribute(attr_name)
      attribute_types[attr_name.to_s]
    end

    def has_attribute?(attr_name)
      attribute_types.key?(attr_name.to_s)
    end

    def find_subtype(type_name)
      return self unless type_name.present?

      type_name = type_name.to_s.camelize

      subclass = local_subtype(type_name)
      subclass ||=
        begin
          if type_name.start_with?('::')
            ActiveSupport::Dependencies.constantize(type_name)
          elsif subtypes_store_full?
            ActiveSupport::Dependencies.constantize(type_name)
          elsif subtypes_namespace
            ActiveSupport::Dependencies.safe_constantize("#{subtypes_namespace}::#{type_name}") || ActiveSupport::Dependencies.constantize(type_name)
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

    protected

    def subtypes_options
      @subtypes_options ||= {}
      if deep_inherited?
        superclass.subtypes_options.merge(@subtypes_options)
      else
        @subtypes_options
      end
    end

    private

    def collection_class_name
      :NestedRecord_Collection
    end

    def type_const
      @type_const ||= if subtypes_namespace
        name.gsub(/\A#{subtypes_namespace}::/, '')
      else
        name
      end
    end

    def subtypes_store_full?
      !subtypes_namespace && subtypes_options.fetch(:full) { true }
    end

    def subtypes_namespace
      return @subtypes_namespace if defined?(@subtypes_namespace)

      namespace = subtypes_options.fetch(:namespace) { false }
      return (@subtypes_namespace = false) unless namespace

      @subtypes_namespace = NestedRecord.lookup_const(self, namespace).name
    end

    def subtypes_underscored?
      subtypes_options.fetch(:underscored) { false }
    end

    def local_subtype?
      @local_subtype == true
    end

    def local_subtypes
      (const_defined?(:LocalTypes, false) && const_get(:LocalTypes, false)) || nil
    end

    def local_subtypes!
      local_subtypes || const_set(:LocalTypes, Module.new)
    end

    def local_subtype(type_name)
      (local_subtypes&.const_defined?(type_name, false) && local_subtypes.const_get(type_name, false)) || nil
    end
  end

  def initialize(attributes = nil)
    super
    self.type = self.class.instance_type if self.class.deep_inherited? && !(attributes&.key?('type') || attributes&.key?(:type))
    _run_initialize_callbacks
  end

  def init_with_attributes(attributes)
    @attributes = attributes
    _run_initialize_callbacks
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
    attribute(attr)
  end

  def query_attribute(attr)
    value = read_attribute(attr)

    case value
    when true        then true
    when false, nil  then false
    else !value.blank?
    end
  end

  def match?(attrs)
    attrs.all? do |attr, others|
      case attr
      when :_is_a?, '_is_a?'
        is_a? others
      when :_instance_of?, '_instance_of?'
        instance_of? others
      when :_not_equal?, '_not_equal?'
        !equal?(others)
      else
        ours = read_attribute(attr)
        if others.is_a? Array
          others.include? ours
        else
          others == ours
        end
      end
    end
  end

  define_model_callbacks :initialize, only: :after
  attribute_method_suffix '?'

  private

  def attribute?(attr)
    query_attribute(attr)
  end
end
