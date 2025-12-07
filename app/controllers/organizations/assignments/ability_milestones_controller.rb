class Organizations::Assignments::AbilityMilestonesController < Organizations::AssignmentsController
  before_action :set_assignment, only: [:show, :update]
  after_action :verify_authorized

  def show
    authorize @assignment
    load_abilities_in_hierarchy
    load_existing_associations
    @form = AssignmentAbilityMilestonesForm.new(@assignment)
    render layout: 'authenticated-horizontal-navigation'
  end

  def update
    authorize @assignment, :update?
    
    @form = AssignmentAbilityMilestonesForm.new(@assignment)
    
    if @form.validate(ability_milestones_params) && @form.save
      redirect_to organization_assignment_path(@organization, @assignment),
                  notice: 'Ability milestone associations were successfully updated.'
    else
      load_abilities_in_hierarchy
      load_existing_associations
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_assignment
    @assignment = @organization.assignments.find(params[:assignment_id])
  end

  def load_abilities_in_hierarchy
    company_hierarchy = @assignment.company.self_and_descendants
    @abilities = Ability.where(organization: company_hierarchy).order(:name)
  end

  def load_existing_associations
    @existing_associations = {}
    @assignment.assignment_abilities.includes(:ability).each do |aa|
      @existing_associations[aa.ability_id] = aa.milestone_level
    end
  end

  def ability_milestones_params
    form_params = params.require(:assignment_ability_milestones_form).permit(ability_milestones: {})
    # Ensure ability_milestones is a hash (Rails may send it as an ActionController::Parameters)
    if form_params[:ability_milestones].present?
      { ability_milestones: form_params[:ability_milestones].to_h }
    else
      { ability_milestones: {} }
    end
  end
end

