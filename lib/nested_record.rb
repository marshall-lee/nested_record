module NestedRecord
  require 'nested_record/version'

  require 'forwardable'

  require 'active_record'
  require 'active_support/dependencies'
  require 'active_support/concern'

  require 'nested_record/macro'
  require 'nested_record/base'
  require 'nested_record/collection'
  require 'nested_record/collection_proxy'
  require 'nested_record/setup'
  require 'nested_record/nested_accessors_setup'
  require 'nested_record/primary_key_check'
  require 'nested_record/methods'
  require 'nested_record/type'
  require 'nested_record/errors'
  require 'nested_record/lookup_const'
  require 'nested_record/macro_recorder'
  require 'nested_record/concern'
end
