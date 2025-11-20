class AspirationDecorator < SimpleDelegator
  include SemanticVersionable

  def initialize(aspiration)
    super(aspiration)
  end

  def version_section_title_for_context
    super("Aspiration")
  end

  def version_section_description_for_context
    super("Aspiration")
  end
end


