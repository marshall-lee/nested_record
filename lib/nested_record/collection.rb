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
    @ary.each { |obj| yield obj }
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
      yield obj if block_given?
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

  def size
    @ary.size
  end

  def select!
    return to_enum(:select!) unless block_given?
    @ary.select! { |obj| yield obj }
    self
  end

  def reject!
    return to_enum(:reject!) unless block_given?
    @ary.reject! { |obj| yield obj }
    self
  end

  def sort_by!
    return to_enum(:sort_by!) unless block_given?
    @ary.sort_by! { |obj| yield obj }
    self
  end

  def reject_by!(attrs)
    attrs = attrs.stringify_keys
    reject! { |obj| obj.match?(attrs) }
  end

  def select
    if block_given?
      dup.select! { |obj| yield obj }
    else
      to_enum(:select)
    end
  end

  %i[select reject sort_by].each do |meth|
    class_eval <<~RUBY, __FILE__, __LINE__ + 1
      def #{meth}
        if block_given?
          dup.#{meth}! { |obj| yield obj }
        else
          to_enum(:#{meth})
        end
      end
    RUBY
  end

  def exists?(attrs)
    attrs = attrs.stringify_keys
    any? { |obj| obj.match?(attrs) }
  end

  def find_by(attrs)
    attrs = attrs.stringify_keys
    find { |obj| obj.match?(attrs) }
  end

  def find_or_initialize_by(attrs, &block)
    attrs = attrs.stringify_keys
    find_by(attrs) || build(attrs, &block)
  end

  private

  def record_class
    self.class.record_class
  end
end
