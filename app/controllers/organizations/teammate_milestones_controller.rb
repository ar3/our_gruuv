class Organizations::TeammateMilestonesController < Organizations::OrganizationNamespaceBaseController
  before_action :set_teammate, only: [:new, :create]
  before_action :set_ability, only: [:new, :create]
  before_action :set_teammate_milestone, only: [:show, :publish, :unpublish, :publish_to_public_profile]
  after_action :verify_authorized

  def new
    authorize TeammateMilestone, :new?
    
    # Load teammate if selected
    if @teammate
      active_tenure = @teammate.active_employment_tenure
      
      @teammate_display = {
        teammate: @teammate,
        name: @teammate.person.display_name,
        casual_name: @teammate.person.casual_name,
        manager: @teammate.current_manager&.display_name,
        external_title: active_tenure&.position&.title&.external_title
      }
    end
    
    # Load ability if selected
    if @ability && @teammate
      @ability_data = load_ability_data(@ability, @teammate)
      @evidence = load_evidence(@teammate, @ability)
      # Load eligible viewers for privacy selection
      @eligible_viewers = eligible_viewers_for_milestone(@teammate)
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
    
    @teammate = CompanyTeammate.where(organization: organization).find_by(id: params[:teammate_id])
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
    
    # Determine privacy level and set published_at accordingly
    privacy_level = params[:privacy_level] || 'private'
    published_at = (privacy_level == 'company') ? Time.current : nil
    published_by_teammate_id = (privacy_level == 'company') ? current_company_teammate.id : nil
    
    # Create the teammate milestone
    teammate_milestone = TeammateMilestone.create!(
      teammate: @teammate,
      ability: @ability,
      milestone_level: milestone_level,
      certifying_teammate: current_company_teammate,
      attained_at: Date.current,
      certification_note: params[:certification_note],
      published_at: published_at,
      published_by_teammate_id: published_by_teammate_id
    )

    # Create observable moment
    ObservableMoments::CreateAbilityMilestoneMomentService.call(
      teammate_milestone: teammate_milestone,
      created_by: current_person
    )

    redirect_to organization_teammate_milestone_path(organization, teammate_milestone),
                notice: 'Milestone awarded successfully!'
  end

  def show
    authorize @teammate_milestone

    @observable_moment = ObservableMoment.find_by(momentable: @teammate_milestone)

    # Find assignments that require at least this milestone level
    assignment_abilities = AssignmentAbility
      .joins(:assignment)
      .where(ability: @teammate_milestone.ability)
      .where('milestone_level <= ?', @teammate_milestone.milestone_level)
      .where(assignments: { company: organization.self_and_descendants })
      .includes(:assignment)
      .distinct

    @required_assignments = assignment_abilities.map do |assignment_ability|
      {
        assignment: assignment_ability.assignment,
        milestone_level: assignment_ability.milestone_level
      }
    end

    # Find positions that require at least this milestone level (direct position milestones)
    position_abilities = PositionAbility
      .joins(:position)
      .joins('INNER JOIN titles ON titles.id = positions.title_id')
      .where(ability: @teammate_milestone.ability)
      .where('position_abilities.milestone_level <= ?', @teammate_milestone.milestone_level)
      .where(titles: { company_id: organization.self_and_descendants.map(&:id) })
      .includes(:position)
      .distinct

    @required_positions = position_abilities.map do |position_ability|
      {
        position: position_ability.position,
        milestone_level: position_ability.milestone_level
      }
    end
  end

  def publish
    authorize @teammate_milestone, :publish?
    
    @teammate_milestone.update!(
      published_at: Time.current,
      published_by_teammate_id: current_company_teammate.id
    )
    
    redirect_to organization_teammate_milestone_path(organization, @teammate_milestone),
                notice: 'Milestone published to company celebration page!'
  end

  def unpublish
    authorize @teammate_milestone, :unpublish?
    
    @teammate_milestone.update!(
      published_at: nil,
      published_by_teammate_id: nil
    )
    
    redirect_to organization_teammate_milestone_path(organization, @teammate_milestone),
                notice: 'Milestone unpublished from company celebration page.'
  end

  def publish_to_public_profile
    authorize @teammate_milestone, :publish_to_public_profile?
    
    @teammate_milestone.update!(
      public_profile_published_at: Time.current
    )
    
    redirect_to organization_teammate_milestone_path(organization, @teammate_milestone),
                notice: 'Milestone published to your public profile!'
  end

  def customize_view
    authorize TeammateMilestone, :new?
    
    # Load current state from params
    query = MilestonesQuery.new(organization, params, current_person: current_person)
    
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @current_spotlight = query.current_spotlight
    
    # Preserve current params for return URL
    return_params = params.except(:controller, :action, :page).permit!.to_h
    @return_url = celebrate_milestones_organization_path(organization, return_params)
    @return_text = "Back to Celebrate Milestones"
    
    render layout: 'overlay'
  end

  def update_view
    authorize TeammateMilestone, :new?
    
    # Build redirect URL with all view customization params
    redirect_params = params.except(:controller, :action, :utf8, :_method, :commit).permit!.to_h
    redirect_to celebrate_milestones_organization_path(organization, redirect_params),
                notice: 'View updated successfully.'
  end

  private

  def set_teammate
    @teammate = CompanyTeammate.where(organization: organization).find_by(id: params[:teammate_id]) if params[:teammate_id].present?
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
      CompanyTeammate.where(organization: organization)
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
        CompanyTeammate.where(organization: organization)
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
      .where(company_teammate: teammate)
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
    
    # Also include abilities from current position's required assignments and direct position milestones
    active_tenure = teammate.active_employment_tenure

    if active_tenure&.position
      active_tenure.position.required_assignments.includes(assignment: :assignment_abilities).each do |position_assignment|
        position_assignment.assignment.assignment_abilities.each do |assignment_ability|
          ability_ids.add(assignment_ability.ability_id)
        end
      end
      active_tenure.position.position_abilities.pluck(:ability_id).each { |id| ability_ids.add(id) }
    end
    
    # Load all abilities with their data
    Ability.unarchived.where(id: ability_ids.to_a, company: organization)
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
      
      # Also check position's required assignments and direct position milestones
      if active_tenure&.position
        position = active_tenure.position
        position.required_assignments.includes(assignment: :assignment_abilities).each do |position_assignment|
          assignment_ability = position_assignment.assignment.assignment_abilities.find_by(ability: ability)
          if assignment_ability
            unless required_milestones.any? { |rm| rm[:assignment] && rm[:assignment].id == position_assignment.assignment.id }
              required_milestones << {
                assignment: position_assignment.assignment,
                milestone_level: assignment_ability.milestone_level
              }
            end
          end
        end
        position.position_abilities.where(ability: ability).each do |position_ability|
          required_milestones << {
            assignment: nil,
            position: position,
            milestone_level: position_ability.milestone_level
          }
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
      .where(company_teammate: teammate)
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
    
    # Also check position's required assignments and direct position milestones
    active_tenure = teammate.active_employment_tenure

    if active_tenure&.position
      position = active_tenure.position
      position.required_assignments.includes(assignment: :assignment_abilities).each do |position_assignment|
        assignment_ability = position_assignment.assignment.assignment_abilities.find_by(ability: ability)
        if assignment_ability
          unless required_assignments.any? { |ra| ra[:assignment].id == position_assignment.assignment.id }
            required_assignments << {
              assignment: position_assignment.assignment,
              milestone_level: assignment_ability.milestone_level
            }
          end
        end
      end
      position.position_abilities.where(ability: ability).each do |position_ability|
        required_assignments << {
          assignment: nil,
          position: position,
          milestone_level: position_ability.milestone_level
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
        .where(company_teammate: teammate, assignment_id: assignment_ids)
        .closed
        .order(official_check_in_completed_at: :desc)
        .limit(5)
        .includes(:assignment)
    end
    
    evidence
  end

  def eligible_viewers_for_milestone(teammate)
    viewers = []
    
    # Add the employee (receiver)
    viewers << {
      person: teammate.person,
      role: 'Employee (Milestone Recipient)'
    }
    
    # Add managers in the hierarchy
    managers = ManagerialHierarchyQuery.new(
      person: teammate.person,
      organization: organization
    ).call
    
    managers.each do |manager|
      viewers << {
        person: Person.find(manager[:person_id]),
        role: "Manager (Level #{manager[:level]})"
      }
    end
    
    # Add people with manage_employment permission in the organization
    employment_managers = CompanyTeammate.where(organization: organization)
                                  .where(can_manage_employment: true, last_terminated_at: nil)
                                  .includes(:person)
    
    employment_managers.each do |manager_teammate|
      # Don't duplicate if already in managers list
      next if managers.any? { |m| m[:person_id] == manager_teammate.person_id }
      next if manager_teammate.person_id == teammate.person_id
      
      viewers << {
        person: manager_teammate.person,
        role: 'Has Manage Employment Permission'
      }
    end
    
    viewers.uniq { |v| v[:person].id }
  end
end

