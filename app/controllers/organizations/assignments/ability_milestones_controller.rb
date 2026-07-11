class Organizations::Assignments::AbilityMilestonesController < Organizations::AssignmentsController
  before_action :set_assignment, only: [:show, :update]
  after_action :verify_authorized

  def show
    authorize @assignment
    load_existing_associations
    load_abilities_for_milestones
    @form = AssignmentAbilityMilestonesForm.new(@assignment)
    render layout: determine_layout
  end

  def update
    authorize @assignment, :update?
    
    @form = AssignmentAbilityMilestonesForm.new(@assignment)
    
    if @form.validate(ability_milestones_params) && @form.save
      redirect_to organization_assignment_path(@organization, @assignment),
                  notice: 'Ability milestone associations were successfully updated.'
    else
      load_existing_associations
      load_abilities_for_milestones
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_assignment
    @assignment = @organization.assignments.find(params[:assignment_id])
  end

  def load_abilities_for_milestones
    abilities = Ability.unarchived
      .where(company: @assignment.company)
      .includes(:department)
      .to_a
      .sort_by { |a| [(a.department&.display_name || "Company-wide").downcase, a.name.to_s.downcase] }

    associated_ids = @existing_associations.keys
    @associated_abilities = abilities.select { |a| associated_ids.include?(a.id) }
    @available_abilities = abilities.reject { |a| associated_ids.include?(a.id) }
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

