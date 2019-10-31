# frozen_string_literal: true

class NestedRecord::Setup
  attr_reader :name, :primary_key, :reject_if_proc

  def initialize(owner, name, **options, &block)
    @options = options
    @owner = owner
    @name = name

    setup_association_attribute
    setup_record_class(&block)
    setup_attributes_writer_opts
    setup_methods_extension
  end

  def record_class
    if @record_class.is_a? String
      @record_class = NestedRecord.lookup_const(@owner, @record_class)
    end
    @record_class
  end

  def primary_key
    return @primary_key if defined? @primary_key

    @primary_key = Array(@options[:primary_key])
    if @primary_key.empty?
      @primary_key = nil
    else
      @primary_key = @primary_key.map(&:to_s)
    end
    @primary_key
  end

  def attributes_writer_strategy
    return unless @options.fetch(:attributes_writer) { true }

    case (strategy = @attributes_writer_opts.fetch(:strategy) { :upsert })
    when :rewrite, :upsert
      return strategy
    else
      raise NestedRecord::ConfigurationError, "Unknown strategy #{strategy.inspect}"
    end
  end

  def primary_check(type)
    if (pkey_attributes = primary_key)
      klass = record_class
    else
      klass = record_class.find_subtype(type)
      while !(pkey_attributes = klass.primary_key) && (klass < NestedRecord::Base)
        klass = klass.superclass
      end
    end
    # TODO: cache this
    NestedRecord::PrimaryKeyCheck.new(klass, pkey_attributes) if pkey_attributes
  end

  private

  def setup_association_attribute
    @owner.attribute name, type, default: default_value
  end

  def setup_record_class(&block)
    if block
      define_local_record_class(&block)
    else
      link_existing_record_class
    end
  end

  def define_local_record_class(&block)
    case (cn = @options.fetch(:class_name) { false })
    when true
      class_name = infer_record_class_name
    when false
      class_name = nil
    when String, Symbol
      class_name = cn.to_s
    else
      raise NestedRecord::ConfigurationError, "Bad :class_name option #{cn.inspect}"
    end
    @record_class = Class.new(NestedRecord::Base, &block)
    @owner.const_set(class_name, @record_class) if class_name
  end

  def link_existing_record_class
    if @options.key? :class_name
      case (cn = @options.fetch(:class_name))
      when String, Symbol
        @record_class = cn.to_s
      else
        raise NestedRecord::ConfigurationError, "Bad :class_name option #{cn.inspect}"
      end
    else
      @record_class = infer_record_class_name
    end
  end

  def infer_record_class_name
    cn = name.to_s.camelize
    cn = cn.singularize if self.is_a?(HasMany)
    cn
  end

  def setup_attributes_writer_opts
    case (aw = @options.fetch(:attributes_writer) { {} })
    when Hash
      @attributes_writer_opts = aw
    when true, false
      @attributes_writer_opts = {}
    when Symbol
      @attributes_writer_opts = { strategy: aw }
    else
      raise NestedRecord::ConfigurationError, "Bad :attributes_writer option #{aw.inspect}"
    end
    @reject_if_proc = @attributes_writer_opts[:reject_if]
  end

  def setup_methods_extension
    methods_extension = build_methods_extension
    @owner.include methods_extension
    @owner.const_set methods_extension_module_name, methods_extension
    @owner.validate methods_extension.validation_method_name
  end

  def methods_extension_module_name
    @methods_extension_module_name ||= :"NestedRecord_#{self.class.name.demodulize}_#{name.to_s.camelize}"
  end

  class HasMany < self
    def type
      @type ||= NestedRecord::Type::Many.new(self)
    end

    def collection_class
      record_class.collection_class
    end

    def collection_proxy_class
      return @owner.const_get(collection_proxy_class_name, false) if @owner.const_defined?(collection_proxy_class_name, false)

      @owner.const_set(
        collection_proxy_class_name,
        ::NestedRecord::CollectionProxy.subclass_for(self)
      )
    end

    def collection_proxy_class_name
      @collection_proxy_class_name ||= :"NestedRecord_#{self.class.name.demodulize}_#{name.to_s.camelize}_CollectionProxy"
    end

    private

    def default_value
      @options.fetch(:default) { [] }
    end

    def build_methods_extension
      NestedRecord::Methods::Many.new(self)
    end
  end

  class HasOne < self
    def type
      @type ||= NestedRecord::Type::One.new(self)
    end

    private

    def default_value
      @options.fetch(:default) { nil }
    end

    def build_methods_extension
      NestedRecord::Methods::One.new(self)
    end
  end
end
