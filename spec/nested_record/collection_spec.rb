require 'spec_helper'

RSpec.describe NestedRecord::Collection do
  nested_model(:Foo) do
    attribute :id, :integer
  end
  nested_model(:Bar, :Foo)

  let(:collection_class) { Foo.collection_class }
  let(:collection) { collection_class.new }

  describe '#<<' do
    it 'adds records to the collection' do
      expect { collection << Foo.new }.to change(collection, :empty?).from(true).to(false)
      expect(collection.first).to be_an_instance_of(Foo)
    end

    it 'refuses to push arbitrary objects' do
      expect { collection << :foo }.to raise_error(NestedRecord::TypeMismatchError)
      expect { collection << nil }.to raise_error(NestedRecord::TypeMismatchError)
    end

    it 'allows to add a record of subtypes' do
      expect { collection << Bar.new }.not_to raise_error
    end
  end

  describe '#sort_by!' do
    it 'sorts collection' do
      collection << Foo.new(id: 2)
      collection << Foo.new(id: 1)

      collection.sort_by!(&:id)
      expect(collection.map(&:id)).to eq [1, 2]
    end
  end

  describe '#size' do
    it 'works' do
      expect(collection.size).to eq 0

      collection << Foo.new(id: 2)
      collection << Foo.new(id: 1)

      expect(collection.size).to eq 2
    end
  end
end
