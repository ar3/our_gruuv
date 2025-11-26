class PositionDecorator < SimpleDelegator
  include DecoratorSemanticVersionable

  def initialize(position)
    super(position)
  end

  def version_section_title_for_context
    super("Position")
  end

  def version_section_description_for_context
    super("Position")
  end
end
