class AssignmentDecorator < SimpleDelegator
  include DecoratorSemanticVersionable

  def initialize(assignment)
    super(assignment)
  end

  def version_section_title_for_context
    super("Assignment")
  end

  def version_section_description_for_context
    super("Assignment")
  end
end
