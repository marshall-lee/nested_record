# frozen_string_literal: true

class NestedRecord::Collection
  class << self
    attr_reader :record_class
  end

  include Enumerable

  def initialize
    @ary = []
  end

  def initialize_dup(orig)
    @ary = orig.to_ary
  end

  def as_json
    @ary.as_json
  end

  def each
    return to_enum(:each) unless block_given?
    @ary.each(&proc)
  end

  def to_ary
    @ary.dup
  end

  def ==(other)
    @ary == other.to_ary
  end

  def <<(obj)
    unless obj.kind_of?(record_class)
      raise NestedRecord::TypeMismatchError, "#{obj.inspect} should be a #{record_class}"
    end
    @ary << obj
    self
  end

  def build(attributes = {})
    record_class.new(attributes).tap do |obj|
      self << obj
    end
  end

  def inspect
    @ary.inspect
  end

  def empty?
    @ary.empty?
  end

  def clear
    @ary.clear
    self
  end

  def length
    @ary.length
  end

  def select!
    return to_enum(:select!) unless block_given?
    @ary.select!(&proc)
    self
  end

  def reject!
    return to_enum(:reject!) unless block_given?
    @ary.reject!(&proc)
    self
  end

  def sort_by!
    return to_enum(:sort_by!) unless block_given?
    @ary.sort_by!(&proc)
    self
  end

  def reject_by!(attrs)
    return to_enum(:reject_by!) unless block_given?
    attrs = attrs.stringify_keys
    reject! { |obj| obj.match?(attrs) }
  end

  def find_by(attrs)
    attrs = attrs.stringify_keys
    find { |obj| obj.match?(attrs) }
  end

  def find_or_initialize_by(attrs)
    attrs = attrs.stringify_keys
    find_by(attrs) || build(attrs)
  end

  private

  def record_class
    self.class.record_class
  end
end
