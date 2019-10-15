require 'spec_helper'

RSpec.describe NestedRecord::Concern do
  nested_concern(:Y) do
    attribute :y, :integer
    has_many_nested :ys, attributes_writer: { strategy: :rewrite } do
      attribute :yy
    end
  end
  nested_model(:XY) do
    attribute :x, :string
    include Y
  end

  it 'adds attributes to the class where it is included' do
    expect(XY.new(x: 'foo', y: 123, ys_attributes: [{ yy: 'yy' }])).to match an_object_having_attributes(
      x: 'foo',
      y: 123,
      ys: [
        an_object_having_attributes(yy: 'yy')
      ]
    )
  end

  context 'with nested concerns' do
    nested_concern(:YZ) do
      include Y
      attribute :z, :boolean
    end
    nested_model(:XYZ) do
      attribute :x, :string
      include YZ
    end

    it 'adds attributes to the class where it is included' do
      expect(XYZ.new(x: 'foo', y: 123, z: true, ys_attributes: [{ yy: 'yy' }])).to match an_object_having_attributes(
        x: 'foo',
        y: 123,
        z: true,
        ys: [
          an_object_having_attributes(yy: 'yy')
        ]
      )
    end
  end
end
