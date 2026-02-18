class Organizations::Assignments::ConsumerAssignmentsController < Organizations::AssignmentsController
  before_action :set_assignment, only: [:show, :update]
  after_action :verify_authorized

  def show
    authorize @assignment, :manage_consumer_assignments?
    
    # Load all assignments in organization hierarchy (excluding current assignment)
    company = @assignment.company
    company_hierarchy_ids = company.self_and_descendants.map(&:id)
    all_assignments = Assignment.unarchived
                                .where(company_id: company_hierarchy_ids)
                                .where.not(id: @assignment.id)
                                .includes(:department, :company)
                                .order(:title)
    
    # Sort by hierarchical department name then assignment name
    @assignments = sort_assignments_by_hierarchy(all_assignments)
    
    # Load existing consumer assignments
    @existing_consumer_assignment_ids = @assignment.consumer_assignments.pluck(:id).to_set
    
    # Set return URL and text for overlay
    return_params = params.except(:controller, :action, :assignment_id).permit!.to_h
    @return_url = organization_assignment_path(@organization, @assignment, return_params)
    @return_text = "Back to #{@assignment.title}"
    
    render layout: 'overlay'
  end

  def update
    authorize @assignment, :manage_consumer_assignments?
    
    # Get selected consumer assignment IDs from params
    selected_ids = Array(params[:consumer_assignment_ids]).map(&:to_i).reject(&:zero?)
    
    # Get current consumer assignment IDs
    current_ids = @assignment.consumer_assignments.pluck(:id).to_set
    
    # Determine which to add and which to remove
    selected_set = selected_ids.to_set
    to_add = selected_set - current_ids
    to_remove = current_ids - selected_set
    
    # Add new relationships
    to_add.each do |consumer_id|
      AssignmentSupplyRelationship.create!(
        supplier_assignment: @assignment,
        consumer_assignment_id: consumer_id
      )
    end
    
    # Remove old relationships
    @assignment.supplier_supply_relationships
                .where(consumer_assignment_id: to_remove.to_a)
                .destroy_all
    
    # Build return URL (don't preserve params for redirect)
    redirect_to organization_assignment_path(@organization, @assignment), 
                notice: 'Consumer assignments were successfully updated.'
  end

  private

  def set_assignment
    @assignment = @organization.assignments.find(params[:assignment_id])
  end

  def sort_assignments_by_hierarchy(assignments)
    # Build sort keys for each assignment
    assignments_with_keys = assignments.map do |assignment|
      # Build hierarchical path: company > dept > subdept > assignment_name
      hierarchy_path = if assignment.department
        assignment.department.display_name
      else
        assignment.company.name
      end
      
      sort_key = "#{hierarchy_path} > #{assignment.title}"
      
      [sort_key, assignment]
    end
    
    # Sort by the hierarchical path string, then return just the assignments
    assignments_with_keys.sort_by(&:first).map(&:last)
  end
end
