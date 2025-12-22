class PromptQuestionSaveService
  def initialize(prompt_question)
    @prompt_question = prompt_question
  end

  def call(attributes = {})
    # Store original position to detect changes
    original_position = @prompt_question.position
    
    @prompt_question.assign_attributes(attributes)
    
    # If position is being changed, resolve collisions
    # (Auto-assignment is handled by the model callback for new records)
    if @prompt_question.position.present? && @prompt_question.position != original_position
      resolve_position_collision
    end
    
    if @prompt_question.save
      { success: true, prompt_question: @prompt_question }
    else
      { success: false, errors: @prompt_question.errors }
    end
  end

  private

  def resolve_position_collision
    target_position = @prompt_question.position
    template = @prompt_question.prompt_template
    
    return unless template.present?
    
    # Find the question currently at the target position (excluding self)
    conflicting_question = template.prompt_questions
      .where(position: target_position)
      .where.not(id: @prompt_question.id)
      .first
    
    return unless conflicting_question
    
    # Recursively bump down the conflicting question
    bump_question_down(conflicting_question, target_position + 1)
  end

  def bump_question_down(question, new_position)
    # Find if there's a conflict at the new position
    template = question.prompt_template
    conflicting_question = template.prompt_questions
      .where(position: new_position)
      .where.not(id: question.id)
      .first
    
    # If there's a conflict, bump that one down first
    if conflicting_question
      bump_question_down(conflicting_question, new_position + 1)
    end
    
    # Now update this question's position
    question.update_column(:position, new_position)
  end

end

