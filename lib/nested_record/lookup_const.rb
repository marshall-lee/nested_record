# frozen_string_literal: true

module NestedRecord
  # Derived from Rails source: https://github.com/rails/rails/blob/98a57aa5f610bc66af31af409c72173cdeeb3c9e/activerecord/lib/active_record/inheritance.rb#L181-L207

  def self.lookup_const(owner, type_name)
    if type_name.start_with?('::')
      ActiveSupport::Dependencies.constantize(type_name)
    else
      candidates = []
      owner.name.scan(/::|$/) { candidates.unshift "#{$`}::#{type_name}" }
      candidates << type_name

      candidates.each do |candidate|
        constant = ActiveSupport::Dependencies.safe_constantize(candidate)
        return constant if candidate == constant.to_s
      end

      raise NameError.new("uninitialized constant #{candidates.first}", candidates.first)
    end
  end
end
