module TestModel
  def active_model(name, &block)
    let!(:"model_#{name.to_s.gsub('::', '_')}") do
      new_active_model(name, &block)
    end
  end

  def nested_concern(name, &block)
    let!(:"concern_#{name.to_s.gsub('::', '_')}") do
      test_consts = (@test_consts ||= [])
      namespace, sname = test_const_dig_name!(name)
      Module.new do
        extend NestedRecord::Concern

        namespace.const_set(sname, self)
        test_consts << self

        class_eval(&block) if block
      end
    end
  end

  def nested_model(name, superclass = NestedRecord::Base, &block)
    let!(:"model_#{name.to_s.gsub('::', '_')}") do
      test_consts = (@test_consts ||= [])
      if superclass.is_a?(Symbol) || superclass.is_a?(String)
        sclass = public_send("model_#{superclass.to_s.gsub('::', '_')}")
      else
        sclass = superclass
      end
      namespace, sname = test_const_dig_name!(name)
      Class.new(sclass) do
        namespace.const_set(sname, self)
        test_consts << self

        class_eval(&block) if block
      end
    end
  end

  module Build
    def new_active_model(name, &block)
      test_consts = (@test_consts ||= [])

      namespace, sname = test_const_dig_name!(name)

      Class.new do
        namespace.const_set(sname, self)
        test_consts << self

        include ActiveModel::Model
        include ActiveModel::Attributes
        include NestedRecord::Macro

        def read_attribute(attr)
          attribute(attr.to_s)
        end

        class_eval(&block) if block
      end
    end
  end

  module Erase
    def erase_test_consts
      Array(@test_consts).reverse_each do |klass|
        ActiveSupport::Dependencies.remove_constant(klass.name)
      end
      ActiveSupport::Dependencies.clear
    end

    def test_const_dig_name!(name)
      parts = name.to_s.split('::')
      name = parts.pop
      namespace = Object
      until parts.empty?
        part = parts.shift
        if namespace.const_defined?(part, false)
          namespace = namespace.const_get(part, false)
        else
          sub = Module.new
          (@test_consts ||= []) << sub
          namespace = namespace.const_set(part, sub)
        end
      end
      [namespace, name]
    end
  end
end
