class Organizations::Assignments::ConsumerAssignmentsController < Organizations::AssignmentsController
  before_action :set_assignment, only: [:show, :update]
  after_action :verify_authorized

  def show
    authorize @assignment, :manage_consumer_assignments?
    load_reliance_collections
    set_return_navigation
    render layout: "overlay"
  end

  def update
    authorize @assignment, :manage_consumer_assignments?

    result = Assignments::RelianceManager.call(
      assignment: @assignment,
      associations: reliance_params
    )

    if result.ok?
      redirect_to organization_assignment_path(@organization, @assignment),
                  notice: "Assignment reliance was successfully updated."
    else
      flash.now[:alert] = result.error
      load_reliance_collections
      set_return_navigation
      render :show, layout: "overlay", status: :unprocessable_entity
    end
  end

  private

  def set_assignment
    @assignment = @organization.assignments.find(params[:assignment_id])
  end

  def set_return_navigation
    return_params = params.except(:controller, :action, :assignment_id).permit!.to_h
    @return_url = organization_assignment_path(@organization, @assignment, return_params)
    @return_text = "Back to #{@assignment.title}"
  end

  def load_reliance_collections
    company_hierarchy_ids = @assignment.company.self_and_descendants.map(&:id)
    all_assignments = Assignment.unarchived
                                .where(company_id: company_hierarchy_ids)
                                .where.not(id: @assignment.id)
                                .includes(:department, :company)
                                .order(:title)

    @existing_directions_by_assignment_id = {}
    @assignment.consumer_assignments.each do |other|
      @existing_directions_by_assignment_id[other.id] = "downstream"
    end
    @assignment.supplier_assignments.each do |other|
      @existing_directions_by_assignment_id[other.id] = "upstream"
    end

    associated_ids = @existing_directions_by_assignment_id.keys
    sorted = sort_assignments_by_hierarchy(all_assignments)

    @associated_assignments = sorted.select { |a| associated_ids.include?(a.id) }
    @available_assignments = sorted.reject { |a| associated_ids.include?(a.id) }
  end

  def reliance_params
    raw = params[:assignment_reliance]
    return {} if raw.blank?

    permitted = raw.permit!
    result = {}
    permitted.each do |other_assignment_id, attrs|
      next if other_assignment_id.blank?

      result[other_assignment_id.to_i] = { direction: attrs[:direction] }
    end
    result
  end

  def sort_assignments_by_hierarchy(assignments)
    assignments_with_keys = assignments.map do |assignment|
      hierarchy_path = if assignment.department
        assignment.department.display_name
      else
        assignment.company.name
      end

      sort_key = "#{hierarchy_path} > #{assignment.title}"
      [sort_key, assignment]
    end

    assignments_with_keys.sort_by(&:first).map(&:last)
  end
end
