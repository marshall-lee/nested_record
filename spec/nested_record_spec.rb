require 'spec_helper'

RSpec.describe NestedRecord do
  describe 'has_one_nested' do
    nested_model(:Bar) do
      attribute :x, :string
      attribute :y, :integer
      attribute :z, :boolean
    end

    active_model(:Foo) do
      has_one_nested :bar
    end

    it 'defines a reader method' do
      expect(Foo.new).to respond_to :bar
    end

    describe 'initialization' do
      it 'allows to initialize with instance of a nested record class' do
        foo = Foo.new(bar: Bar.new)
        expect(foo.bar).to be_an_instance_of Bar
      end

      it 'preserves nested attributes' do
        foo = Foo.new(bar: Bar.new(x: 'xx'))
        expect(foo.bar.x).to eq 'xx'
      end

      it 'allows to initialize with a nil value' do
        foo = Foo.new(bar: nil)
        expect(foo.bar).to be nil
      end

      it 'does not allow to initialize with anything else' do
        expect { Foo.new(bar: :baz) }.to raise_error NestedRecord::TypeMismatchError
      end
    end

    context 'with plural model name' do
      nested_model(:Points) do
        attribute :x, :string
        attribute :y, :integer
        attribute :z, :boolean
      end

      active_model(:Foo) do
        has_one_nested :points
      end

      it 'properly locates the model class' do
        expect(Foo.new.build_points).to be_an_instance_of(Points)
      end
    end

    describe 'writer' do
      it 'is defined' do
        foo = Foo.new
        expect(foo).to respond_to(:bar=)
      end

      it 'allows to assign instance of a nested record class' do
        foo = Foo.new
        foo.bar = Bar.new
        expect(foo.bar).to be_an_instance_of Bar
      end

      it 'preserves nested attributes' do
        foo = Foo.new
        foo.bar = Bar.new(x: 'xx')
        expect(foo.bar.x).to eq 'xx'
      end

      it 'allows to assign a nil value' do
        foo = Foo.new
        foo.bar = nil
        expect(foo.bar).to be nil
      end

      it 'does not allow to assign anything else' do
        foo = Foo.new
        expect { foo.bar = :baz }.to raise_error NestedRecord::TypeMismatchError
      end
    end

    describe 'attributes writer' do
      it 'is defined' do
        foo = Foo.new
        expect(foo).to respond_to(:bar_attributes=)
      end

      context 'when turned off' do
        active_model(:Foo) do
          has_one_nested :bar, attributes_writer: false
        end

        it 'is not defined' do
          foo = Foo.new
          expect(foo).not_to respond_to(:bar_attributes=)
        end
      end

      it 'allows initialize with nested attributes' do
        foo = Foo.new(bar_attributes: { x: 'xx', y: '123', z: '0' })
        expect(foo.bar).to match an_object_having_attributes(x: 'xx', y: 123, z: false)
      end

      it 'allows to assign nested attributes' do
        foo = Foo.new
        foo.bar_attributes = { x: 'xx', y: '123', z: '0' }
        expect(foo.bar).to match an_object_having_attributes(x: 'xx', y: 123, z: false)
      end
    end
  end

  describe 'has_many_nested' do
    nested_model(:Bar) do
      attribute :x, :string
      attribute :y, :integer
      attribute :z, :boolean
    end

    active_model(:Foo) do
      has_many_nested :bars
    end

    it 'defines a reader method' do
      expect(Foo.new).to respond_to :bars
    end

    describe 'when used with block' do
      active_model(:Foo) do
        has_many_nested :bars do
          def filter_by_something; end
        end
      end

      it 'adds extension method to the collection' do
        expect(Foo.new.bars).to respond_to(:filter_by_something)
      end
    end

    describe 'initialization' do
      it 'allows to initialize with an array of instances of a nested record class' do
        foo = Foo.new(bars: [Bar.new, Bar.new])
        expect(foo.bars).to match [an_instance_of(Bar), an_instance_of(Bar)]
      end

      it 'preserves nested attributes' do
        foo = Foo.new(bars: [Bar.new(x: 'xx'), Bar.new(x: 'yy')])
        expect(foo.bars).to match [
          an_object_having_attributes(x: 'xx'),
          an_object_having_attributes(x: 'yy')
        ]
      end

      it 'allows to initialize with an empty array' do
        foo = Foo.new(bars: [])
        expect(foo.bars).to be_empty
      end
    end

    describe 'writer' do
      it 'is defined' do
        foo = Foo.new
        expect(foo).to respond_to(:bars=)
      end

      it 'allows to assign instance of a nested record class' do
        foo = Foo.new
        foo.bars = [Bar.new, Bar.new]
        expect(foo.bars).to match [
          an_instance_of(Bar),
          an_instance_of(Bar)
        ]
      end

      it 'preserves nested attributes' do
        foo = Foo.new
        foo.bars = [Bar.new(x: 'xx'), Bar.new(x: 'yy')]
        expect(foo.bars).to match [
          an_object_having_attributes(x: 'xx'),
          an_object_having_attributes(x: 'yy')
        ]
      end

      it 'allows to assign an empty array' do
        foo = Foo.new
        foo.bars = []
        expect(foo.bars).to be_empty
      end
    end

    describe 'attributes writer' do
      it 'is defined' do
        foo = Foo.new
        expect(foo).to respond_to(:bars_attributes=)
      end

      context 'when turned off' do
        active_model(:Foo) do
          has_many_nested :bars, attributes_writer: false
        end

        it 'is not defined' do
          foo = Foo.new
          expect(foo).not_to respond_to(:bars_attributes=)
        end
      end

      it 'allows initialize with a collection of attributes' do
        foo = Foo.new(bars_attributes: [{ x: 'xx' }, { x: 'yy' }])
        expect(foo.bars).to match [
          an_object_having_attributes(x: 'xx'),
          an_object_having_attributes(x: 'yy')
        ]
      end

      it 'allows to assign attributes' do
        foo = Foo.new
        foo.bars_attributes = [{ x: 'xx' }, { x: 'yy' }]
        expect(foo.bars).to match [
          an_object_having_attributes(x: 'xx'),
          an_object_having_attributes(x: 'yy')
        ]
      end

      it 'allows to use a rails form hash' do
        foo = Foo.new(
          bars_attributes: {
            '0' => { 'x' => 'xx' },
            '1' => { 'x' => 'yy' }
          }
        )
        expect(foo.bars).to match [
          an_object_having_attributes(x: 'xx'),
          an_object_having_attributes(x: 'yy')
        ]
      end

      context 'with :reject_if option' do
        active_model(:Foo) do
          has_many_nested :bars,
                          attributes_writer: {
                            reject_if: ->(attributes) { attributes['_destroy'].present? }
                          }
        end
        nested_model(:Bar) do
          attribute :id, :integer
          attr_accessor :_destroy
        end

        it 'filters records' do
          foo = Foo.new(
            bars_attributes: [
              { id: '1', _destroy: '' },
              { id: '2', _destroy: '1' },
              { id: '3', _destroy: '' },
            ]
          )
          expect(foo.bars).to match [
            an_object_having_attributes(id: 1),
            an_object_having_attributes(id: 3)
          ]
        end
      end
    end
  end

  describe 'class_name resolution with namespaced models' do
    active_model('A::B::Foo') do
      has_one_nested :bar
    end

    context 'when nested model is defined in the model namespace' do
      nested_model('A::B::Foo::Bar')

      it 'locates the nested model' do
        foo = A::B::Foo.new(bar_attributes: {})
        expect(foo.bar).to be_an_instance_of(A::B::Foo::Bar)
      end
    end

    context 'when nested model is defined in the common namespace' do
      nested_model('A::B::Bar')

      it 'locates the nested model' do
        foo = A::B::Foo.new(bar_attributes: {})
        expect(foo.bar).to be_an_instance_of(A::B::Bar)
      end
    end

    context 'when nested model is defined in the upper namespace' do
      nested_model('A::Bar')

      it 'locates the nested model' do
        foo = A::B::Foo.new(bar_attributes: {})
        expect(foo.bar).to be_an_instance_of(A::Bar)
      end
    end
  end
end
