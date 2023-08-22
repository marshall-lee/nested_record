# frozen_string_literal: true

module NestedRecord
  # TODO: Remove this when we drop support for Rails < 7.0
  if ActiveSupport::VERSION::MAJOR < 7
    def self.constantize(type_name)
      ActiveSupport::Dependencies.constantize(type_name)
    end

    def self.safe_constantize(type_name)
      ActiveSupport::Dependencies.safe_constantize(type_name)
    end
  else
    def self.constantize(type_name)
      type_name.constantize
    end

    def self.safe_constantize(type_name)
      type_name.safe_constantize
    end
  end

  # Derived from Rails source: https://github.com/rails/rails/blob/98a57aa5f610bc66af31af409c72173cdeeb3c9e/activerecord/lib/active_record/inheritance.rb#L181-L207
  def self.lookup_const(owner, type_name)
    if type_name.start_with?('::')
      NestedRecord.constantize(type_name)
    else
      candidates = []
      owner.name.scan(/::|$/) { candidates.unshift "#{$`}::#{type_name}" }
      candidates << type_name

      candidates.each do |candidate|
        constant = NestedRecord.safe_constantize(candidate)
        return constant if candidate == constant.to_s
      end

      raise NameError.new("uninitialized constant #{candidates.first}", candidates.first)
    end
  end
end
