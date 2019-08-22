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

    describe 'build_ method' do
      it 'builds an object' do
        foo = Foo.new
        foo.build_bar(x: 'xx')
        expect(foo.bar).to be_an_instance_of(Bar)
        expect(foo.bar.x).to eq 'xx'
      end

      it 'rewrites the existing object' do
        foo = Foo.new(bar: Bar.new(x: 'x'))
        foo.build_bar(x: 'xx')
        expect(foo.bar).to be_an_instance_of(Bar)
        expect(foo.bar.x).to eq 'xx'
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
    end

    describe 'bang ! method' do
      it 'initializes an object if it is missing' do
        foo = Foo.new(bar: nil)
        foo.bar!
        expect(foo.bar).to be_an_instance_of(Bar)
        expect(foo.bar.x).to be nil
      end

      it 'uses existing object' do
        foo = Foo.new(bar: Bar.new(x: 'xx'))
        foo.bar!
        expect(foo.bar).to be_an_instance_of(Bar)
        expect(foo.bar.x).to eq 'xx'
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

      context 'with :upsert strategy' do
        active_model(:Foo) do
          has_one_nested :bar, attributes_writer: { strategy: :upsert }
        end

        it 'updates the existing data' do
          foo = Foo.new(bar_attributes: { x: 'x', y: 1 })
          expect(foo.bar).to match an_object_having_attributes(x: 'x', y: 1, z: nil)
          foo.bar_attributes = { x: 'xx', z: '1' }
          expect(foo.bar).to match an_object_having_attributes(x: 'xx', y: 1, z: true)
        end
      end
    end

    describe 'validations' do
      nested_model(:Bar) do
        attribute :x, :string
        validates :x, presence: true
      end

      it 'validates the record and adds an error entry' do
        foo = Foo.new(bar: Bar.new(x: 'x'))
        expect(foo).to be_valid
        expect(foo.errors).to be_empty
        foo = Foo.new(bar: Bar.new(x: ''))
        expect(foo).not_to be_valid
        expect(foo.errors['bar.x']).to eq ["can't be blank"]
      end
    end
  end

  describe 'has_many_nested' do
    nested_model(:Bar) do
      def_primary_uuid :id
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

    describe 'when used with custom :class_name' do
      active_model(:Foo) do
        has_many_nested :bars, class_name: 'Barr'
      end
      nested_model(:Barr) do
        def_primary_uuid :id
        attribute :a, :integer
        attribute :b, :integer
      end

      it 'uses a custom class' do
        foo = Foo.new(bars_attributes: [{ a: 1, b: 2 }])
        expect(foo.bars.first).to_not be_an_instance_of(Bar)
        expect(foo.bars).to match [an_object_having_attributes(a: 1, b: 2)]
      end
    end

    describe 'when used with class_name: <unknown>' do
      it 'raises an error' do
        expect do
          new_active_model(:Fooo) do
            has_many_nested :bars, class_name: []
          end
        end.to raise_error(NestedRecord::ConfigurationError, 'Bad :class_name option []')
      end
    end

    describe 'when used with block' do
      active_model(:Foo) do
        has_many_nested :bars do
          def_primary_uuid :id
          attribute :a, :integer
          attribute :b, :integer
          collection_methods do
            def filter_by_something; end
          end
        end
      end

      it 'defines an anonymous record class' do
        foo = Foo.new(bars_attributes: [{ a: 1, b: 2 }])
        expect(foo.bars.first).to_not be_an_instance_of(Bar)
        expect(foo.bars).to match [an_object_having_attributes(a: 1, b: 2)]
        expect(foo.bars).to respond_to(:filter_by_something)
      end
    end

    describe 'when used with block and class_name: true' do
      active_model(:Foo) do
        has_many_nested :bars, class_name: true do
          def_primary_uuid :id
        end
      end

      it 'names a class' do
        expect(Foo::Bar).to be < NestedRecord::Base
        foo = Foo.new(bars_attributes: [{}])
        expect(foo.bars.first).to be_an_instance_of(Foo::Bar)
      end
    end

    describe 'when used with block and class_name: "String"' do
      active_model(:Foo) do
        has_many_nested :bars, class_name: 'Barr' do
          def_primary_uuid :id
        end
      end

      it 'names a class' do
        expect(Foo::Barr).to be < NestedRecord::Base
        foo = Foo.new(bars_attributes: [{}])
        expect(foo.bars.first).to be_an_instance_of(Foo::Barr)
      end
    end

    describe 'when used with block and class_name: <unknown>' do
      it 'raises an error' do
        expect do
          new_active_model(:Fooo) do
            has_many_nested :bars, class_name: [] do
            end
          end
        end.to raise_error(NestedRecord::ConfigurationError, 'Bad :class_name option []')
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

      context 'when used with invalid :attributes_writer option' do
        it 'raises an error' do
          expect do
            new_active_model(:Fooo) do
              has_many_nested :bars, attributes_writer: 'foo'
            end
          end.to raise_error(NestedRecord::ConfigurationError, 'Bad :attributes_writer option "foo"')
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
          attribute :id, :integer, primary: true
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

      context 'with :unknown strategy' do
        it 'raises an error' do
          expect do
            new_active_model(:Fooo) do
              has_many_nested :bars, attributes_writer: :unknown do
                attribute :val, :string
              end
            end
          end.to raise_error(NestedRecord::ConfigurationError, 'Unknown strategy :unknown')
        end
      end

      context 'with :rewrite strategy' do
        active_model(:Foo) do
          has_many_nested :bars, attributes_writer: :rewrite do
            attribute :val, :string
          end
        end

        it 'replaces the whole contents of the collection' do
          foo = Foo.new(bars_attributes: [{ val: 'foo' }, { val: 'bar' }])
          foo.bars_attributes = [{ val: 'ping' }, { val: 'pong' }]
          expect(foo.bars).to match [an_object_having_attributes(val: 'ping'), an_object_having_attributes(val: 'pong')]
        end
      end

      context 'with :upsert strategy when primary key specified on association level' do
        active_model(:Foo) do
          has_many_nested :bars, attributes_writer: { strategy: :upsert }, primary_key: :id do
            attribute :id, :integer
            attribute :val, :string
          end
        end

        it 'upserts the data' do
          foo = Foo.new(bars_attributes: [{ id: 1, val: 'x' }, { id: 2, val: 'y' }])
          expect(foo.bars).to match [
            an_object_having_attributes(id: 1, val: 'x'),
            an_object_having_attributes(id: 2, val: 'y')
          ]

          foo.bars_attributes = [{ id: 3, val: 'z' }, { id: 2, val: 'yy' }]
          expect(foo.bars).to match [
            an_object_having_attributes(id: 1, val: 'x'),
            an_object_having_attributes(id: 2, val: 'yy'),
            an_object_having_attributes(id: 3, val: 'z')
          ]
        end
      end

      context 'with :upsert strategy when primary key specified on model level' do
        active_model(:Foo) do
          has_many_nested :bars, attributes_writer: { strategy: :upsert } do
            primary_key :id
            attribute :id, :integer
            attribute :val, :string
          end
        end

        it 'upserts the data' do
          foo = Foo.new(bars_attributes: [{ id: 1, val: 'x' }, { id: 2, val: 'y' }])
          expect(foo.bars).to match [
            an_object_having_attributes(id: 1, val: 'x'),
            an_object_having_attributes(id: 2, val: 'y')
          ]

          foo.bars_attributes = [{ id: 3, val: 'z' }, { id: 2, val: 'yy' }]
          expect(foo.bars).to match [
            an_object_having_attributes(id: 1, val: 'x'),
            an_object_having_attributes(id: 2, val: 'yy'),
            an_object_having_attributes(id: 3, val: 'z')
          ]
        end
      end

      context 'with :upsert strategy when primary key specified on model attribute level' do
        active_model(:Foo) do
          has_many_nested :bars, attributes_writer: { strategy: :upsert } do
            attribute :id, :integer, primary: true
            attribute :val, :string
          end
        end

        it 'upserts the data' do
          foo = Foo.new(bars_attributes: [{ id: 1, val: 'x' }, { id: 2, val: 'y' }])
          expect(foo.bars).to match [
            an_object_having_attributes(id: 1, val: 'x'),
            an_object_having_attributes(id: 2, val: 'y')
          ]

          foo.bars_attributes = [{ id: 3, val: 'z' }, { id: 2, val: 'yy' }]
          expect(foo.bars).to match [
            an_object_having_attributes(id: 1, val: 'x'),
            an_object_having_attributes(id: 2, val: 'yy'),
            an_object_having_attributes(id: 3, val: 'z')
          ]
        end
      end

      context 'with :upsert strategy when primary key specified on model attribute level and subtyping is used' do
        active_model(:Foo) do
          has_many_nested :bars, attributes_writer: { strategy: :upsert } do
            attribute :id, :integer, primary: true
            attribute :value, :string
            subtype :x
            subtype :y
          end
        end

        it 'upserts the data according to its type' do
          foo = Foo.new(bars_attributes: [{ type: 'x', id: '1', value: 'x' }, { type: 'y', id: '2', value: 'y2' }])
          expect(foo.bars).to match [
            an_object_having_attributes(id: 1, value: 'x'),
            an_object_having_attributes(id: 2, value: 'y2')
          ]

          foo.bars_attributes = [{ type: 'y', id: '3', value: 'y3' }, { type: 'x', id: '1', value: 'xx' }, { type: 'y', id: '2', value: 'yy' }]
          expect(foo.bars).to match [
            an_object_having_attributes(id: 1, value: 'xx'),
            an_object_having_attributes(id: 2, value: 'yy'),
            an_object_having_attributes(id: 3, value: 'y3')
          ]
        end
      end

      context 'with :upsert strategy when primary key is specific for each subtype' do
        active_model(:Foo) do
          has_many_nested :bars, attributes_writer: { strategy: :upsert } do
            attribute :value, :string
            subtype :x do
              attribute :xid, :integer, primary: true
            end
            subtype :y do
              attribute :yid, :integer, primary: true
            end
          end
        end

        it 'upserts the data according to its type' do
          foo = Foo.new(bars_attributes: [{ type: 'x', xid: '1', value: 'x' }, { type: 'y', yid: '2', value: 'y2' }])
          expect(foo.bars).to match [
            an_object_having_attributes(xid: 1, value: 'x'),
            an_object_having_attributes(yid: 2, value: 'y2')
          ]

          foo.bars_attributes = [{ type: 'x', xid: '2', value: 'x2' }, { type: 'y', yid: '1', value: 'y' }, { type: 'x', xid: '1', value: 'xx' }]
          expect(foo.bars).to match [
            an_object_having_attributes(xid: 1, value: 'xx'),
            an_object_having_attributes(yid: 2, value: 'y2'),
            an_object_having_attributes(xid: 2, value: 'x2'),
            an_object_having_attributes(yid: 1, value: 'y')
          ]
        end
      end

      context 'with :upsert strategy when primary key is not specified at all' do
        active_model(:Foo) do
          has_many_nested :bars, attributes_writer: { strategy: :upsert } do
            attribute :id, :integer
            attribute :val, :string
          end
        end

        it 'upserts the data' do
          foo = Foo.new
          expect { foo.bars_attributes = [{ id: 0 }] }
            .to raise_error(NestedRecord::ConfigurationError, /You should specify a primary_key/)
        end
      end
    end

    describe 'validations' do
      nested_model(:Bar) do
        def_primary_uuid :id
        attribute :x, :string
        validates :x, presence: true
      end

      it 'validates the record and adds an error entry' do
        foo = Foo.new(bars: [Bar.new(x: 'x')])
        expect(foo).to be_valid
        expect(foo.errors).to be_empty
        foo = Foo.new(bars: [Bar.new(x: 'y'), Bar.new(x: '')])
        expect(foo).not_to be_valid
        expect(foo.errors['bars[1].x']).to eq ["can't be blank"]
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
