class NestedRecord::MacroRecorder
  def initialize
    @macros = []
  end

  attr_reader :macros

  MACROS = %i[
    include
    attribute
    def_primary_uuid
    primary_key
    has_one_nested
    has_many_nested
    subtype subtypes
    collection_methods
    validate validates validates! validates_with validates_each
    validates_absence_of
    validates_acceptance_of
    validates_confirmation_of
    validates_exclusion_of
    validates_format_of
    validates_inclusion_of
    validates_length_of
    validates_numericality_of
    validates_presence_of
    validates_size_of
    after_initialize
    before_validation after_validation
  ].freeze.each do |meth|
    define_method(meth) do |*args, &block|
      @macros << [meth, args, block]
    end
  end

  def apply_to(mod_or_class)
    macros = @macros
    mod_or_class.module_eval do
      macros.each do |meth, args, block|
        public_send(meth, *args, &block)
      end
    end
  end
end
