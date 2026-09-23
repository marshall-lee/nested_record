require 'spec_helper'

# Params as date_select / time_select submit them.
RSpec.describe 'multiparameter attributes' do
  nested_model(:Slot) do
    attribute :start, :time, default: '00:00'
    attribute :day, :date
    attribute :at, :datetime
    attribute :note, :string
  end

  active_model(:Foo) do
    has_one_nested :slot
    has_many_nested :slots, attributes_writer: { strategy: :rewrite }
  end

  let(:date_params) { { 'day(1i)' => '2026', 'day(2i)' => '9', 'day(3i)' => '23' } }
  let(:time_params) do
    { 'start(1i)' => '2000', 'start(2i)' => '1', 'start(3i)' => '1', 'start(4i)' => '14', 'start(5i)' => '30' }
  end

  it 'assigns a date from date_select params' do
    expect(Slot.new(date_params).day).to eq Date.new(2026, 9, 23)
  end

  it 'assigns a time from time_select params' do
    expect(Slot.new(time_params).start).to eq Time.utc(2000, 1, 1, 14, 30)
  end

  it 'assigns a datetime from datetime_select params' do
    slot = Slot.new('at(1i)' => '2026', 'at(2i)' => '9', 'at(3i)' => '23', 'at(4i)' => '8', 'at(5i)' => '5')
    expect(slot.at).to eq Time.utc(2026, 9, 23, 8, 5)
  end

  it 'assigns plain attributes in the same hash' do
    slot = Slot.new(date_params.merge('note' => 'hi'))
    expect(slot).to have_attributes(day: Date.new(2026, 9, 23), note: 'hi')
  end

  it 'sets nil when every part is blank' do
    slot = Slot.new(day: '2026-01-01')
    slot.assign_attributes('day(1i)' => '', 'day(2i)' => '', 'day(3i)' => '')
    expect(slot.day).to be_nil
  end

  it 'applies the i and f casts' do
    slot = Slot.new('start(4i)' => '07', 'start(5i)' => '09', 'start(6f)' => '5.5')
    expect([slot.start.hour, slot.start.min, slot.start.sec, slot.start.usec]).to eq [7, 9, 5, 500_000]
  end

  it 'passes through has_one_nested attributes writers' do
    foo = Foo.new
    foo.slot_attributes = date_params.merge(time_params)
    expect(foo.slot).to have_attributes(day: Date.new(2026, 9, 23), start: Time.utc(2000, 1, 1, 14, 30))
  end

  it 'passes through has_many_nested attributes writers' do
    foo = Foo.new
    foo.slots_attributes = [date_params, time_params]
    expect(foo.slots.map(&:day)).to eq [Date.new(2026, 9, 23), nil]
    expect(foo.slots.map(&:start)).to eq [Time.utc(2000, 1, 1, 0, 0), Time.utc(2000, 1, 1, 14, 30)]
  end

  it 'still raises for an unknown attribute' do
    expect { Slot.new('nope(1i)' => '1') }.to raise_error(ActiveModel::UnknownAttributeError)
  end
end
