module NestedRecord::Concern
  extend Forwardable

  def_delegators :macro_recorder, *(NestedRecord::MacroRecorder::MACROS - [:include])

  def included(mod_or_class)
    super
    macro_recorder.apply_to(mod_or_class)
  end

  def macro_recorder
    @macro_recorder ||= NestedRecord::MacroRecorder.new
  end
end
