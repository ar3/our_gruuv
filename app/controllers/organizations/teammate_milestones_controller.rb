class Organizations::TeammateMilestonesController < Organizations::OrganizationNamespaceBaseController
  before_action :set_teammate, only: [:new, :create]
  before_action :set_ability, only: [:new, :create]
  before_action :set_teammate_milestone, only: [:show]
  after_action :verify_authorized

  def new
    authorize TeammateMilestone, :new?
    
    # Load teammate if selected
    if @teammate
      active_tenure = ActiveEmploymentTenureQuery.new(
        person: @teammate.person,
        organization: organization
      ).first
      
      @teammate_display = {
        teammate: @teammate,
        name: @teammate.person.display_name,
        casual_name: @teammate.person.casual_name,
        manager: @teammate.current_manager&.display_name,
        position_type: active_tenure&.position&.position_type&.external_title
      }
    end
    
    # Load ability if selected
    if @ability && @teammate
      @ability_data = load_ability_data(@ability, @teammate)
      @evidence = load_evidence(@teammate, @ability)
    end
  end

  def select_teammate
    authorize TeammateMilestone, :new?
    
    @eligible_teammates = load_eligible_teammates
    
    # Set return URL and text for overlay
    @return_url = params[:return_url] || new_organization_teammate_milestone_path(organization)
    @return_text = params[:return_text] || 'Back to Award Milestone'
    
    render layout: 'overlay'
  end

  def select_ability
    authorize TeammateMilestone, :new?
    
    @teammate = organization.teammates.find_by(id: params[:teammate_id])
    unless @teammate
      redirect_to new_organization_teammate_milestone_path(organization), alert: 'Teammate not found.'
      return
    end
    
    @abilities_data = load_abilities_for_teammate(@teammate)
    
    # Set return URL and text for overlay
    @return_url = params[:return_url] || new_organization_teammate_milestone_path(organization, teammate_id: @teammate.id)
    @return_text = params[:return_text] || 'Back to Award Milestone'
    
    render layout: 'overlay'
  end

  def create
    authorize TeammateMilestone, :create?
    
    unless @teammate && @ability && params[:milestone_level].present?
      redirect_to new_organization_teammate_milestone_path(organization), 
                  alert: 'Please select a teammate, ability, and milestone level.'
      return
    end
    
    milestone_level = params[:milestone_level].to_i
    
    # Validate milestone level
    unless (1..5).include?(milestone_level)
      redirect_to new_organization_teammate_milestone_path(organization, 
                                                          teammate_id: @teammate.id, 
                                                          ability_id: @ability.id),
                  alert: 'Invalid milestone level.'
      return
    end
    
    # Check if this milestone has already been awarded
    if @teammate.teammate_milestones.exists?(ability: @ability, milestone_level: milestone_level)
      redirect_to new_organization_teammate_milestone_path(organization,
                                                            teammate_id: @teammate.id,
                                                            ability_id: @ability.id),
                  alert: 'This milestone has already been awarded.'
      return
    end
    
    # Create the teammate milestone
    teammate_milestone = TeammateMilestone.create!(
      teammate: @teammate,
      ability: @ability,
      milestone_level: milestone_level,
      certified_by: current_person,
      attained_at: Date.current
    )
    
    # Create observable moment
    ObservableMoments::BaseObservableMomentService.call(
      momentable: teammate_milestone,
      company: organization,
      created_by: current_person,
      primary_potential_observer: current_company_teammate,
      moment_type: 'ability_milestone',
      occurred_at: Time.current
    )
    
    redirect_to organization_teammate_milestone_path(organization, teammate_milestone),
                notice: 'Milestone awarded successfully!'
  end

  def show
    authorize @teammate_milestone
    
    @observable_moment = ObservableMoment.find_by(momentable: @teammate_milestone)
  end

  private

  def set_teammate
    @teammate = organization.teammates.find_by(id: params[:teammate_id]) if params[:teammate_id].present?
  end

  def set_ability
    @ability = organization.abilities.find_by(id: params[:ability_id]) if params[:ability_id].present?
  end

  def set_teammate_milestone
    @teammate_milestone = TeammateMilestone.find(params[:id])
  end

  def load_eligible_teammates
    current_teammate = current_company_teammate
    
    # If user has manage_employment permission on their own company_teammate
    if current_teammate.can_manage_employment?
      # Show all active company teammates except current user
      organization.teammates
        .where.not(id: current_teammate.id)
        .where(last_terminated_at: nil)
        .includes(:person, :employment_tenures)
        .order('people.last_name, people.first_name')
    else
      # Check if user has reports
      reports = EmployeeHierarchyQuery.new(
        person: current_teammate.person,
        organization: organization
      ).call
      
      if reports.any?
        # Get teammates for all reports
        report_person_ids = reports.map { |r| r[:person_id] }
        organization.teammates
          .where(person_id: report_person_ids, last_terminated_at: nil)
          .includes(:person, :employment_tenures)
          .order('people.last_name, people.first_name')
      else
        # No reports - return empty and show message
        []
      end
    end
  end

  def load_abilities_for_teammate(teammate)
    abilities_data = []
    
    # Get all assignment tenures (including ended) for this teammate
    all_tenures = AssignmentTenure
      .where(teammate: teammate)
      .joins(:assignment)
      .where(assignments: { company: organization.self_and_descendants })
      .includes(assignment: :assignment_abilities)
    
    # Collect all unique abilities from assignment tenures
    ability_ids = Set.new
    all_tenures.each do |tenure|
      tenure.assignment.assignment_abilities.each do |assignment_ability|
        ability_ids.add(assignment_ability.ability_id)
      end
    end
    
    # Also include abilities from current position's required assignments
    active_tenure = ActiveEmploymentTenureQuery.new(
      person: teammate.person,
      organization: organization
    ).first
    
    if active_tenure&.position
      active_tenure.position.required_assignments.includes(assignment: :assignment_abilities).each do |position_assignment|
        position_assignment.assignment.assignment_abilities.each do |assignment_ability|
          ability_ids.add(assignment_ability.ability_id)
        end
      end
    end
    
    # Load all abilities with their data
    Ability.where(id: ability_ids.to_a, organization: organization.self_and_descendants)
          .includes(:assignment_abilities)
          .order(:name)
          .each do |ability|
      # Get teammate's current milestone for this ability
      teammate_milestone = teammate.teammate_milestones.find_by(ability: ability)
      current_milestone = teammate_milestone&.milestone_level || 0
      
      # Get required milestones from assignments
      required_milestones = []
      all_tenures.each do |tenure|
        assignment_ability = tenure.assignment.assignment_abilities.find_by(ability: ability)
        if assignment_ability
          required_milestones << {
            assignment: tenure.assignment,
            milestone_level: assignment_ability.milestone_level
          }
        end
      end
      
      # Also check position's required assignments
      if active_tenure&.position
        active_tenure.position.required_assignments.includes(assignment: :assignment_abilities).each do |position_assignment|
          assignment_ability = position_assignment.assignment.assignment_abilities.find_by(ability: ability)
          if assignment_ability
            # Only add if not already in required_milestones (to avoid duplicates)
            unless required_milestones.any? { |rm| rm[:assignment].id == position_assignment.assignment.id }
              required_milestones << {
                assignment: position_assignment.assignment,
                milestone_level: assignment_ability.milestone_level
              }
            end
          end
        end
      end
      
      abilities_data << {
        ability: ability,
        current_milestone: current_milestone,
        required_milestones: required_milestones
      }
    end
    
    abilities_data
  end

  def load_ability_data(ability, teammate)
    teammate_milestone = teammate.teammate_milestones.find_by(ability: ability)
    current_milestone = teammate_milestone&.milestone_level || 0
    
    # Get all assignments that require this ability
    assignment_tenures = AssignmentTenure
      .where(teammate: teammate)
      .joins(assignment: :assignment_abilities)
      .where(assignment_abilities: { ability: ability })
      .where(assignments: { company: organization.self_and_descendants })
      .includes(assignment: :assignment_abilities)
    
    required_assignments = []
    assignment_tenures.each do |tenure|
      assignment_ability = tenure.assignment.assignment_abilities.find_by(ability: ability)
      if assignment_ability
        required_assignments << {
          assignment: tenure.assignment,
          milestone_level: assignment_ability.milestone_level
        }
      end
    end
    
    {
      ability: ability,
      current_milestone: current_milestone,
      awarded_milestone: teammate_milestone,
      required_assignments: required_assignments
    }
  end

  def load_evidence(teammate, ability)
    evidence = {
      observations: [],
      assignment_check_ins: []
    }
    
    # Get observations where chosen teammate is observer OR observed, and current teammate can view
    all_observations = Observation.where(company: organization)
                                  .includes(:observer, :observed_teammates)
                                  .order(observed_at: :desc)
    
    visibility_query = ObservationVisibilityQuery.new(current_person, organization)
    
    visible_observations = all_observations.select do |obs|
      # Check if teammate is observer or observed
      is_observer_or_observed = obs.observer_id == teammate.person_id ||
                                obs.observed_teammates.any? { |ot| ot.id == teammate.id }
      
      if is_observer_or_observed
        # Check if current teammate can view using ObservationVisibilityQuery
        visibility_query.visible_to?(obs)
      else
        false
      end
    end
    
    evidence[:observations] = visible_observations.first(10)
    
    # Get most recent assignment check-in for assignments that require this ability
    assignment_ids = AssignmentAbility
      .where(ability: ability)
      .joins(:assignment)
      .where(assignments: { company: organization.self_and_descendants })
      .pluck(:assignment_id)
    
    if assignment_ids.any?
      evidence[:assignment_check_ins] = AssignmentCheckIn
        .where(teammate: teammate, assignment_id: assignment_ids)
        .closed
        .order(official_check_in_completed_at: :desc)
        .limit(5)
        .includes(:assignment)
    end
    
    evidence
  end
end

