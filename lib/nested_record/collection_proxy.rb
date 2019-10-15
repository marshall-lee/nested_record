class NestedRecord::CollectionProxy
  extend Forwardable
  include Enumerable

  class << self
    def subclass_for(setup)
      Class.new(self) do
        methods = setup.collection_class.public_instance_methods
        methods -= NestedRecord::Collection.public_instance_methods
        methods -= NestedRecord::CollectionProxy.public_instance_methods(false)
        def_delegators :__collection__, *methods unless methods.empty?
        @setup = setup
      end
    end

    def __nested_record_setup__
      @setup
    end
  end

  def initialize(owner)
    @owner = owner
  end

  def method_missing(method_name, *args, &block)
    collection = __collection__
    if collection.respond_to? method_name
      collection.public_send(method_name, *args, &block)
    else
      super
    end
  end

  def respond_to_missing?(method_name, _)
    super || __collection__.respond_to?(method_name)
  end

  def build(attributes = {})
    __collection__.build(attributes) do |record|
      ensure_primary! record
      yield record if block_given?
    end
  end

  def __build__(attributes)
    __collection__.build(attributes)
  end

  def find_or_initialize_by(attributes)
    __collection__.find_or_initialize_by(attributes) do |record|
      ensure_primary! record
      yield record if block_given?
    end
  end

  def_delegators :__collection__, *(NestedRecord::Collection.public_instance_methods(false) - public_instance_methods(false))

  def __collection__
    @owner.read_attribute(self.class.__nested_record_setup__.name)
  end

  private

  def ensure_primary!(record)
    check = self.class.__nested_record_setup__.primary_check(record.read_attribute('type'))
    check&.perform!(__collection__, record)
  end
end
