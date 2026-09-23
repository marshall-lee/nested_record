require 'spec_helper'

RSpec.describe 'dirty tracking' do
  nested_model(:Bar) do
    attribute :x, :string
    attribute :y, :integer, primary: true
  end

  active_model(:Foo) do
    include ActiveModel::Dirty

    has_one_nested :bar
    has_many_nested :bars
  end

  def persisted_foo
    Foo.new(bar: Bar.new(x: 'old', y: 1), bars: [Bar.new(x: 'old', y: 1)]).tap(&:changes_applied)
  end

  describe 'has_one_nested' do
    it 'detects an in-place edit' do
      foo = persisted_foo
      foo.bar.x = 'new'
      expect(foo).to be_changed
      expect(foo.changed).to eq ['bar']
    end

    it 'detects an upsert through the attributes writer' do
      foo = persisted_foo
      foo.bar_attributes = { x: 'new' }
      expect(foo.changed).to eq ['bar']
    end

    it 'stays clean when the nested record is only read' do
      foo = persisted_foo
      foo.bar.x
      expect(foo).not_to be_changed
    end

    it 'detects assigning nil' do
      foo = persisted_foo
      foo.bar = nil
      expect(foo.changed).to eq ['bar']
    end

    it 'detects assigning a record to nil' do
      foo = Foo.new(bar: nil).tap(&:changes_applied)
      foo.bar = Bar.new(x: 'new')
      expect(foo.changed).to eq ['bar']
    end
  end

  describe 'has_many_nested' do
    it 'detects an in-place edit' do
      foo = persisted_foo
      foo.bars.first.x = 'new'
      expect(foo.changed).to eq ['bars']
    end

    it 'detects an added record' do
      foo = persisted_foo
      foo.bars.build(x: 'added', y: 2)
      expect(foo.changed).to eq ['bars']
    end

    it 'detects an upsert through the attributes writer' do
      foo = persisted_foo
      foo.bars_attributes = [{ x: 'new', y: 1 }]
      expect(foo.changed).to eq ['bars']
    end

    it 'stays clean when the collection is only read' do
      foo = persisted_foo
      foo.bars.to_a
      expect(foo).not_to be_changed
    end

    it 'detects assigning an empty collection' do
      foo = persisted_foo
      foo.bars = []
      expect(foo.changed).to eq ['bars']
    end
  end

  it 'marks the attribute types mutable' do
    expect(Foo.attribute_types.values_at('bar', 'bars')).to all be_mutable
  end

  describe NestedRecord::Base do
    it 'is not equal to nil' do
      expect(Bar.new).not_to eq nil
    end

    it 'is not equal to a non-record' do
      expect(Bar.new).not_to eq 'bar'
    end
  end

  describe NestedRecord::Collection do
    it 'is not equal to nil' do
      expect(Foo.new(bars: []).bars).not_to eq nil
    end
  end
end
