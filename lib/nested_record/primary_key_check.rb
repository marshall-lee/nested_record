class NestedRecord::PrimaryKeyCheck
  def initialize(klass, pkey_attributes)
    @klass = klass
    @pkey_attributes = pkey_attributes
    @params = [klass, pkey_attributes]
  end

  attr_reader :params

  def hash
    params.hash
  end

  def ==(other)
    self.class === other && params == other.params
  end
  alias eql? ==

  def build_pkey(obj)
    pkey = { _is_a?: @klass }
    if obj.is_a? @klass
      pkey[:_not_equal?] = obj
      @pkey_attributes.each do |name|
        pkey[name] = obj.read_attribute(name)
      end
    elsif obj.respond_to? :[]
      @pkey_attributes.each do |name|
        value = obj[name]
        if (type = @klass.type_for_attribute(name))
          value = type.cast(value)
        end
        pkey[name] = value
      end
    else
      fail
    end
    pkey
  end

  def perform!(collection, obj)
    pkey = build_pkey(obj)
    raise NestedRecord::PrimaryKeyError if collection.exists?(pkey)
  end
end
