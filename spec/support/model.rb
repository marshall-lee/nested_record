module TestModel
  def active_model(name, &block)
    let!(:"model_#{name.to_s.gsub('::', '_')}") do
      test_models = (@test_models ||= [])

      namespace, sname = test_model_dig_name!(name)

      Class.new do
        namespace.const_set(sname, self)
        test_models << self

        include ActiveModel::Model
        include ActiveModel::Attributes
        include NestedRecord::Macro

        class_eval(&block) if block
      end
    end
  end

  def nested_model(name, superclass = NestedRecord::Base, &block)
    let!(:"model_#{name.to_s.gsub('::', '_')}") do
      test_models = (@test_models ||= [])
      if superclass.is_a?(Symbol) || superclass.is_a?(String)
        sclass = public_send("model_#{superclass.to_s.gsub('::', '_')}")
      else
        sclass = superclass
      end
      namespace, sname = test_model_dig_name!(name)
      Class.new(sclass) do
        namespace.const_set(sname, self)
        test_models << self

        class_eval(&block) if block
      end
    end
  end

  private

  module Erase
    def erase_test_models
      Array(@test_models).reverse_each do |klass|
        ActiveSupport::Dependencies.remove_constant(klass.name)
      end
      ActiveSupport::Dependencies.clear
    end

    def test_model_dig_name!(name)
      parts = name.to_s.split('::')
      name = parts.pop
      namespace = Object
      until parts.empty?
        part = parts.shift
        if namespace.const_defined?(part, false)
          namespace = namespace.const_get(part, false)
        else
          sub = Module.new
          (@test_models ||= []) << sub
          namespace = namespace.const_set(part, sub)
        end
      end
      [namespace, name]
    end
  end
end
