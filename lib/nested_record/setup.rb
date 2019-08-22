# frozen_string_literal: true

class NestedRecord::Setup
  attr_reader :name, :primary_key, :reject_if_proc

  def initialize(owner, name, **options, &block)
    @options = options
    @owner = owner
    @name = name

    if block
      case (cn = options.fetch(:class_name) { false })
      when true
        cn = name.to_s.camelize
        cn = cn.singularize if self.is_a?(HasMany)
        class_name = cn
      when false
        class_name = nil
      when String, Symbol
        class_name = cn.to_s
      else
        raise NestedRecord::ConfigurationError, "Bad :class_name option #{cn.inspect}"
      end
      @record_class = Class.new(NestedRecord::Base, &block)
      @owner.const_set(class_name, @record_class) if class_name
    else
      if options.key? :class_name
        case (cn = options.fetch(:class_name))
        when String, Symbol
          @record_class = cn.to_s
        else
          raise NestedRecord::ConfigurationError, "Bad :class_name option #{cn.inspect}"
        end
      else
        cn = name.to_s.camelize
        cn = cn.singularize if self.is_a?(HasMany)
        @record_class = cn
      end
    end

    case (aw = options.fetch(:attributes_writer) { {} })
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

    @methods_extension = build_methods_extension

    @owner.attribute @name, type, default: default_value
    @owner.include @methods_extension
    @owner.validate @methods_extension.validation_method_name
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

  private

  class HasMany < self
    def type
      @type ||= NestedRecord::Type::Many.new(self)
    end

    def collection_class
      record_class.collection_class
    end

    private

    def default_value
      []
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
      nil
    end

    def build_methods_extension
      NestedRecord::Methods::One.new(self)
    end
  end
end
