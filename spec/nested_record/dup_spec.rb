require 'spec_helper'

RSpec.describe 'duplicating the owner' do
  nested_model(:Baz) do
    attribute :z, :string
  end

  nested_model(:Bar) do
    attribute :x, :string
    attribute :y, :integer, primary: true
    has_one_nested :baz
  end

  active_model(:Foo) do
    include ActiveModel::Dirty

    has_one_nested :bar
    has_many_nested :bars
  end

  it 'copies has_one_nested records' do
    foo = Foo.new(bar: Bar.new(x: 'a'))
    copy = foo.dup
    copy.bar.x = 'b'
    expect(foo.bar.x).to eq 'a'
    expect(copy.bar.x).to eq 'b'
  end

  it 'copies has_one_nested records that were read before dup' do
    foo = Foo.new(bar: Bar.new(x: 'a'))
    foo.bar
    copy = foo.dup
    copy.bar.x = 'b'
    expect(foo.bar.x).to eq 'a'
  end

  it 'copies records nested inside nested records' do
    foo = Foo.new(bar: Bar.new(baz: Baz.new(z: 'a')))
    copy = foo.dup
    copy.bar.baz.z = 'b'
    expect(foo.bar.baz.z).to eq 'a'
  end

  it 'copies has_many_nested collections and their records' do
    foo = Foo.new(bars: [Bar.new(x: 'a', y: 1)])
    copy = foo.dup
    copy.bars.build(x: 'b', y: 2)
    copy.bars.first.x = 'c'
    expect(foo.bars.map(&:x)).to eq ['a']
    expect(copy.bars.map(&:x)).to eq %w[c b]
  end

  it 'keeps nil values' do
    copy = Foo.new(bar: nil).dup
    expect(copy.bar).to be_nil
    expect(copy.bars).to be_empty
  end

  it 'keeps the original record clean' do
    foo = Foo.new(bar: Bar.new(x: 'a')).tap(&:changes_applied)
    foo.dup
    expect(foo).not_to be_changed
  end

  it 'still returns the built record from build_' do
    foo = Foo.new
    foo.build_bar(x: 'a').x = 'b'
    expect(foo.bar.x).to eq 'b'
  end
end
