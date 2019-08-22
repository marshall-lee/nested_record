require 'spec_helper'

RSpec.describe NestedRecord::Type::Many do
  nested_model(:Foo) do
    attribute :id, :integer
    attribute :x, :integer
    attribute :s, :string

    after_initialize { self.id = 1000 + x }
  end
  let(:collection_class) { Foo.collection_class }
  let(:setup) { double(record_class: Foo, collection_class: collection_class) }
  let(:type) { described_class.new(setup) }

  describe '#deserialize' do
    subject { type.deserialize('[{"x": 1, "s": "yeah"}, {"x": 2, "s": "hoorah"}]') }

    it 'deserializes a json string to record object' do
      is_expected.to be_an_instance_of(collection_class)
      is_expected.to match [an_object_having_attributes(id: 1001, x: 1, s: 'yeah'), an_object_having_attributes(id: 1002, x: 2, s: 'hoorah')]
    end
  end
end
