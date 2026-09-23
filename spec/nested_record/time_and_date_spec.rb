require 'spec_helper'

RSpec.describe 'time and date attributes' do
  nested_model(:Slot) do
    attribute :start, :time, default: '00:00'
    attribute :day, :date
  end

  active_model(:Foo) do
    include ActiveModel::Dirty

    has_one_nested :slot
    has_many_nested :slots, attributes_writer: { strategy: :rewrite }
  end

  let(:type) { Foo.attribute_types['slot'] }

  it 'applies the time default' do
    expect(Slot.new.start).to eq Time.utc(2000, 1, 1, 0, 0)
  end

  it 'casts time and date strings' do
    slot = Slot.new(start: '14:30', day: '2026-09-23')
    expect(slot.start).to eq Time.utc(2000, 1, 1, 14, 30)
    expect(slot.day).to eq Date.new(2026, 9, 23)
  end

  it 'leaves a blank date nil' do
    expect(Slot.new(day: '').day).to be_nil
  end

  it 'round-trips through JSON' do
    slot = Slot.new(start: '14:30', day: '2026-09-23')
    json = type.serialize(slot)
    expect(ActiveSupport::JSON.decode(json)).to eq(
      'start' => '2000-01-01T14:30:00.000Z',
      'day' => '2026-09-23'
    )
    expect(type.deserialize(json)).to have_attributes(start: slot.start, day: slot.day)
  end

  it 'assigns string values through the attributes writer' do
    foo = Foo.new
    foo.slot_attributes = { start: '08:15', day: '2026-01-31' }
    expect(foo.slot).to have_attributes(start: Time.utc(2000, 1, 1, 8, 15), day: Date.new(2026, 1, 31))
  end

  it 'detects an in-place change of a time or date' do
    foo = Foo.new(slot: Slot.new(start: '08:00', day: '2026-01-01')).tap(&:changes_applied)
    foo.slot.start = '09:00'
    expect(foo.changed).to eq ['slot']

    foo.changes_applied
    foo.slot.day = '2026-01-02'
    expect(foo.changed).to eq ['slot']
  end

  it 'stays clean when the same time is assigned again' do
    foo = Foo.new(slot: Slot.new(start: '08:00', day: '2026-01-01')).tap(&:changes_applied)
    foo.slot.start = '08:00'
    foo.slot.day = '2026-01-01'
    expect(foo).not_to be_changed
  end
end
