require 'spec_helper'

RSpec.describe NestedRecord::Base do
  nested_model(:Foo) do
    attribute :x, :string
    attribute :y, :integer
    attribute :z, :boolean
  end

  describe '.deep_inherited?' do
    subject { Foo.deep_inherited? }

    context 'when subclassing from NestedRecord::Base' do
      nested_model(:Foo, NestedRecord::Base)

      it { is_expected.to be false }
    end

    context 'when subclassing from NestedRecord::Base' do
      nested_model(:Bar, NestedRecord::Base)
      nested_model(:Foo, :Bar)

      it { is_expected.to be true }
    end
  end

  describe '.collection_class' do
    subject { Foo.collection_class }

    it 'is a subclass of NestedRecord::Collection' do
      is_expected.to be < NestedRecord::Collection
    end

    it 'holds a reference to record_class' do
      is_expected.to have_attributes(record_class: Foo)
    end

    context 'with .collection_methods' do
      before do
        Foo.collection_methods do
          def filter_by_something; end
        end
      end

      it 'has collection methods defined' do
        expect(Foo.collection_class.method_defined?(:filter_by_something)).to be true
      end
    end

    context 'when inherited' do
      nested_model(:Bar)
      nested_model(:Foo, :Bar)

      it 'uses ancestor collection class as a subclass' do
        is_expected.to be < Bar.collection_class
      end
    end
  end

  describe '.new' do
    context 'with after_initialize callbacks' do
      nested_model(:Foo) do
        attribute :x, :integer
        attribute :y, :integer
        attribute :z, :integer

        after_initialize { self.z = 1234 }
      end

      it 'calls them' do
        expect(Foo.new(x: 1, y: 2)).to match an_object_having_attributes(x: 1, y: 2, z: 1234)
      end
    end

    context 'with inheritance' do
      nested_model(:Bar)
      nested_model(:Foo, :Bar)
      nested_model(:Baz)

      it 'returns an instance of subclass' do
        expect(Bar.new).to be_an_instance_of(Bar)
        expect(Bar.new(type: 'Foo')).to be_an_instance_of(Foo)
      end

      it 'sets a type attribute' do
        expect(Foo.new.type).to eq 'Foo'
      end

      it 'raises error when type is not a subclass' do
        expect { Bar.new(type: 'Baz') }.to raise_error(NestedRecord::InvalidTypeError)
      end

      it 'raises error when type is invalid' do
        expect { Bar.new(type: 'Buzz') }.to raise_error(NestedRecord::InvalidTypeError)
      end

      context 'with namespaced models and subtypes full: true' do
        nested_model('A::Bar') do
          subtypes full: true
        end
        nested_model('A::Foo', 'A::Bar')

        it 'looks up for a subclass globally' do
         expect(A::Bar.new(type: 'A::Foo')).to be_an_instance_of(A::Foo)
          expect { A::Bar.new(type: 'Foo') }.to raise_error(NestedRecord::InvalidTypeError)
        end
      end

      context 'with namespaced models and subtypes full: false' do
        nested_model('A::Bar') do
          subtypes full: false
        end
        nested_model('A::Foo', 'A::Bar')

        it 'looks up for a subclass through all namespaces' do
          expect(A::Bar.new(type: 'A::Foo')).to be_an_instance_of(A::Foo)
          expect(A::Bar.new(type: 'Foo')).to be_an_instance_of(A::Foo)
        end
      end

      context 'with subtypes :namespace option' do
        nested_model('A::Bar') do
          subtypes namespace: 'A::Bars'
        end
        nested_model('A::Bars::Foo', 'A::Bar')
        nested_model('A::Foo', 'A::Bar')

        it 'looks up for a subclass through a specific namespace' do
          expect(A::Bar.new(type: 'Foo')).to be_an_instance_of(A::Bars::Foo)
        end

        it 'sets a shortened :type attribute' do
          expect(A::Bars::Foo.new.type).to eq 'Foo'
        end

        it 'keeps full class type for records outside namespace' do
          expect(A::Bar.new(type: 'A::Foo').type).to eq 'A::Foo'
        end
      end

      context 'with subtypes underscored: true' do
        nested_model('A::Bar') do
          subtypes underscored: true, full: false
        end
        nested_model('A::Bar::Foo', 'A::Bar')

        it 'looks up for a subclass through a specific namespace' do
          expect(A::Bar.new(type: 'bar/foo')).to be_an_instance_of(A::Bar::Foo)
        end

        it 'sets a shortened :type attribute' do
          expect(A::Bar::Foo.new.type).to eq 'a/bar/foo'
        end
      end

      context 'with local subtypes' do
        nested_model('Baz') do
          subtypes underscored: true
          attribute :x, :integer

          subtype :foo do
            attribute :y, :integer
          end

          subtype :bar do
            attribute :z, :integer
          end
        end

        it 'looks up local subtypes' do
          foo = Baz.new(type: 'foo', x: 1, y: 2)
          bar = Baz.new(type: 'bar', x: 1, z: 3)
          expect(foo).to be_an_instance_of Baz::LocalTypes::Foo
          expect(bar).to be_an_instance_of Baz::LocalTypes::Bar
          expect(foo).to match an_object_having_attributes(x: 1, y: 2)
          expect(bar).to match an_object_having_attributes(x: 1, z: 3)
        end

        it 'sets a local type when called on subtypes' do
          expect(Baz::LocalTypes::Foo.new).to match an_object_having_attributes(type: 'foo')
          expect(Baz::LocalTypes::Bar.new).to match an_object_having_attributes(type: 'bar')
        end
      end

      context 'with local subtypes in anonymous records' do
        nested_model('Baz') do
          has_one_nested :aux do
            subtypes underscored: true
            attribute :x, :integer

            subtype :foo do
              attribute :y, :integer
            end

            subtype :bar do
              attribute :z, :integer
            end
          end
        end

        it 'looks up local subtypes' do
          baz = Baz.new
          foo = baz.build_aux(type: 'foo', x: 1, y: 2)
          expect(foo).to match an_object_having_attributes(x: 1, y: 2)
          bar = baz.build_aux(type: 'bar', x: 1, z: 3)
          expect(bar).to match an_object_having_attributes(x: 1, z: 3)
        end
      end
    end
  end

  describe '.instantiate' do
    context 'with after_initialize callbacks' do
      nested_model(:Foo) do
        attribute :x, :integer
        attribute :y, :integer
        attribute :z, :integer

        after_initialize { self.z = 1234 }
      end

      it 'calls them' do
        expect(Foo.instantiate('x' => 1, 'y' => 2)).to match an_object_having_attributes(x: 1, y: 2, z: 1234)
      end
    end
  end

  describe '.subtype' do
    nested_model('Baz') do
      subtype :foo
      subtype :bar
    end

    it 'defines subclasses in Subtypes namespace' do
      expect(Baz::LocalTypes).to be_an_instance_of Module
      expect(Baz::LocalTypes::Foo).to be < Baz
      expect(Baz::LocalTypes::Bar).to be < Baz
    end
  end

  describe '#as_json' do
    it 'serializes as a hash of attributes' do
      foo = Foo.new(x: 'aa', y: 123, z: true)
      expect(foo.as_json).to eq('x' => 'aa', 'y' => 123, 'z' => true)
    end
  end

  describe '#read_attribute' do
    it 'reads attribute value' do
      foo = Foo.new(x: 'aa')
      expect(foo.read_attribute(:x)).to eq 'aa'
    end

    it 'returns nil for unknown attributes' do
      foo = Foo.new(x: 'aa')
      expect(foo.read_attribute(:lol)).to be nil
    end
  end

  describe '#query_attribute' do
    it 'returns true if boolean attribute is true' do
      expect(Foo.new(z: true).query_attribute(:z)).to eq true
    end

    it 'returns true if boolean attribute is false' do
      expect(Foo.new(z: false).query_attribute(:z)).to eq false
    end

    it 'returns true if string attribute is non-blank' do
      expect(Foo.new(x: 'a').query_attribute(:x)).to eq true
    end

    it 'returns false if string attribute is blank' do
      expect(Foo.new(x: '').query_attribute(:x)).to eq false
    end

    it 'works with suffix ? version' do
      foo = Foo.new(x: '1', z: false)
      expect(foo.x?).to eq true
      expect(foo.z?).to eq false
      foo = Foo.new(x: '', z: true)
      expect(foo.x?).to eq false
      expect(foo.z?).to eq true
    end
  end

  describe '#match?' do
    let(:record) { Foo.new(x: 'aa', y: 123, z: true) }

    it 'matches by a single value' do
      expect(record.match?(x: 'aa')).to be true
      expect(record.match?(x: 'ab')).to be false
    end

    it 'matches by a set of values' do
      expect(record.match?(x: 'aa', y: 123)).to be true
      expect(record.match?(x: 'aa', y: 111)).to be false
    end

    it 'matches by a range of values' do
      expect(record.match?(x: ['aa', 'bb'])).to be true
      expect(record.match?(x: ['bb', 'cc'])).to be false
    end
  end
end
