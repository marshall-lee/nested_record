class NestedRecord::NestedAccessorsSetup
  def initialize(owner, name, class_name: false, default: {}, &block)
    raise ArgumentError, 'block is required for .nested_accessors_in' unless block

    recorder = NestedRecord::MacroRecorder.new
    recorder.instance_eval(&block)

    @has_one_setup = owner.has_one_nested(name, class_name: class_name, default: default, attributes_writer: { strategy: :rewrite }) do
      recorder.apply_to(self)
    end

    @extension = Module.new

    macros = [
      recorder,
      *recorder.macros.select do |macro, args, _|
        macro == :include && args.first.is_a?(NestedRecord::Concern)
      end.map! { |_, args, _| args.first.macro_recorder }
    ].flat_map(&:macros)

    macros.each do |macro, args, _block|
      case macro
      when :attribute
        attr_name = args.first
        delegate(attr_name)
        delegate("#{attr_name}?")
        delegate1("#{attr_name}=")
      when :has_one_nested
        assoc_name = args.first
        delegate(assoc_name)
        delegate("#{assoc_name}!")
        delegate1("#{assoc_name}=")
        delegate1("#{assoc_name}_attributes=")
      when :has_many_nested
        assoc_name = args.first
        delegate(assoc_name)
        delegate1("#{assoc_name}=")
        delegate1("#{assoc_name}_attributes=")
      end
    end

    owner.include(@extension)
  end

  def name
    @has_one_setup.name
  end

  private

  def delegate(meth)
    @extension.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      def #{meth}
        #{name}!.#{meth}
      end
    RUBY
  end

  def delegate1(meth)
    @extension.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      def #{meth}(arg)
        #{name}!.#{meth}(arg)
      end
    RUBY
  end
end
