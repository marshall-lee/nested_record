module NestedRecord
  class Error < StandardError; end
  class TypeMismatchError < Error; end
  class InvalidTypeError < Error; end
  class ConfigurationError < Error; end
end
