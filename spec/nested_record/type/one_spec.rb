require 'spec_helper'

RSpec.describe NestedRecord::Type::One do
  nested_model(:Foo) do
    attribute :id, :integer
    attribute :x, :integer
    attribute :s, :string

    after_initialize { self.id = 1000 }
  end
  let(:setup) { double(record_class: Foo) }
  let(:type) { described_class.new(setup) }

  describe '#deserialize' do
    subject { type.deserialize('{"x": 123, "s": "yeah"}') }

    it 'deserializes a json string to record object' do
      is_expected.to be_an_instance_of(Foo)
      is_expected.to match an_object_having_attributes(id: 1000, x: 123, s: 'yeah')
    end
  end
end
