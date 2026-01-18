class AssignmentCheckInForm < Reform::Form
  # Define form properties - Reform handles Rails integration automatically
  property :employee_rating
  property :manager_rating
  property :employee_private_notes
  property :manager_private_notes
  property :actual_energy_percentage
  property :employee_personal_alignment
  property :status, virtual: true  # This is a form-only field for completion status
  property :assignment_id, virtual: true  # This is needed for form submission

  # Use ActiveModel validations
  validates :assignment_id, presence: true
  validates :status, inclusion: { in: %w[draft complete] }, allow_blank: true
  validates :employee_rating, inclusion: { in: %w[working_to_meet meeting exceeding] }, allow_blank: true
  validates :manager_rating, inclusion: { in: %w[working_to_meet meeting exceeding] }, allow_blank: true
  validates :actual_energy_percentage, numericality: { in: 0..100 }, allow_blank: true
  validates :employee_personal_alignment, inclusion: { in: %w[love like neutral prefer_not only_if_necessary] }, allow_blank: true

  # Reform automatically handles save - we just need to customize the logic
  def save
    return false unless valid?
    
    # Let Reform sync the form data to the model first
    super
    
    # Handle completion status based on view mode
    if status == 'complete'
      if view_mode == :employee
        model.complete_employee_side!
      elsif view_mode == :manager
        model.complete_manager_side!(completed_by: current_company_teammate)
      end
    elsif status == 'draft'
      if view_mode == :employee
        model.uncomplete_employee_side!
      elsif view_mode == :manager
        model.uncomplete_manager_side!
      end
    end
    
    # Save the model
    model.save
  end

  # Helper method to get current company teammate (passed from controller)
  def current_company_teammate
    @current_company_teammate
  end

  # Helper method to set current company teammate
  def current_company_teammate=(teammate)
    @current_company_teammate = teammate
  end

  # Helper method to get view mode (passed from controller)
  def view_mode
    @view_mode
  end

  # Helper method to set view mode
  def view_mode=(mode)
    @view_mode = mode
  end
end


