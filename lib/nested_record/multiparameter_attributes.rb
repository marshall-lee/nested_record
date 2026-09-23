# frozen_string_literal: true

# Accepts date_select / time_select params such as "day(1i)" => "2026".
# Mirrors ActiveRecord::AttributeAssignment: parts are grouped into a hash
# ({ 1 => 2026, 2 => 9, 3 => 23 }) that the ActiveModel date and time types cast.
module NestedRecord::MultiparameterAttributes
  private

  def _assign_attributes(attributes)
    multiparameter_attributes = nil
    plain_attributes = {}

    attributes.each do |key, value|
      if key.to_s.include?('(')
        (multiparameter_attributes ||= {})[key.to_s] = value
      else
        plain_attributes[key] = value
      end
    end

    super(plain_attributes)
    assign_multiparameter_attributes(multiparameter_attributes) if multiparameter_attributes
  end

  def assign_multiparameter_attributes(pairs)
    grouped = Hash.new { |hash, name| hash[name] = {} }

    pairs.each do |key, value|
      name, position, cast = key.match(/\A(\w+)\((\d+)([if])?\)\z/)&.captures
      raise ActiveModel::UnknownAttributeError.new(self, key) unless name

      value = nil if value.to_s.empty?
      value = value.public_send(:"to_#{cast}") if value && cast
      grouped[name][position.to_i] ||= value
    end

    grouped.each do |name, values|
      _assign_attribute(name, values.each_value.all?(&:nil?) ? nil : values)
    end
  end
end
