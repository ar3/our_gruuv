class Organizations::Abilities::AssignmentMilestonesController < Organizations::AbilitiesController
  before_action :set_ability, only: [:show, :update]

  def show
    authorize @ability
    load_assignments_in_hierarchy
    load_existing_associations
    @form = AbilityAssignmentMilestonesForm.new(@ability)
    render layout: determine_layout
  end

  def update
    authorize @ability, :update?
    
    @form = AbilityAssignmentMilestonesForm.new(@ability)
    
    if @form.validate(assignment_milestones_params) && @form.save
      redirect_to organization_ability_path(@organization, @ability),
                  notice: 'Assignment milestone associations were successfully updated.'
    else
      load_assignments_in_hierarchy
      load_existing_associations
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_ability
    @ability = @organization.abilities.find(params[:ability_id])
  end

  def load_assignments_in_hierarchy
    org_hierarchy = @ability.organization.self_and_descendants
    @assignments = Assignment.where(company: org_hierarchy).order(:title)
  end

  def load_existing_associations
    @existing_associations = {}
    @ability.assignment_abilities.includes(:assignment).each do |aa|
      @existing_associations[aa.assignment_id] = aa.milestone_level
    end
  end

  def assignment_milestones_params
    form_params = params.require(:ability_assignment_milestones_form).permit(assignment_milestones: {})
    # Ensure assignment_milestones is a hash (Rails may send it as an ActionController::Parameters)
    if form_params[:assignment_milestones].present?
      { assignment_milestones: form_params[:assignment_milestones].to_h }
    else
      { assignment_milestones: {} }
    end
  end
end

