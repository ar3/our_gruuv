class RelevantAbilitiesQuery
  def initialize(teammate:, organization:)
    @teammate = teammate
    @organization = organization
  end

  def call
    return [] unless @teammate

    org_hierarchy = organization_hierarchy
    relevant_ability_ids = collect_relevant_ability_ids(org_hierarchy)
    
    return [] if relevant_ability_ids.empty?

    build_ability_data(relevant_ability_ids)
  end

  private

  def organization_hierarchy
    @organization.self_and_descendants
  end

  def collect_relevant_ability_ids(org_hierarchy)
    relevant_ability_ids = Set.new
    
    # Find abilities where employee has milestone attainments
    milestone_ability_ids = abilities_from_milestones(org_hierarchy)
    relevant_ability_ids.merge(milestone_ability_ids)
    
    # Find abilities required by active assignments
    assignment_ability_ids = abilities_from_active_assignments(org_hierarchy)
    relevant_ability_ids.merge(assignment_ability_ids)
    
    relevant_ability_ids
  end

  def abilities_from_milestones(org_hierarchy)
    @teammate.teammate_milestones
              .joins(:ability)
              .where(abilities: { organization: org_hierarchy })
              .pluck(:ability_id)
  end

  def abilities_from_active_assignments(org_hierarchy)
    AssignmentAbility
      .joins(assignment: :assignment_tenures)
      .where(assignment_tenures: { teammate: @teammate, ended_at: nil })
      .where(assignments: { company: org_hierarchy })
      .pluck(:ability_id)
  end

  def build_ability_data(relevant_ability_ids)
    abilities = load_abilities_with_associations(relevant_ability_ids)
    
    abilities.map do |ability|
      {
        ability: ability,
        milestone_attainments: milestone_attainments_for(ability),
        assignment_requirements: assignment_requirements_for(ability)
      }
    end
  end

  def load_abilities_with_associations(ability_ids)
    Ability.where(id: ability_ids)
           .includes(:teammate_milestones, assignment_abilities: [:assignment])
           .order(:name)
  end

  def milestone_attainments_for(ability)
    @teammate.teammate_milestones
              .where(ability: ability)
              .by_milestone_level
              .includes(:ability, :certified_by)
  end

  def assignment_requirements_for(ability)
    AssignmentAbility
      .joins(assignment: :assignment_tenures)
      .where(assignment_tenures: { teammate: @teammate, ended_at: nil })
      .where(ability: ability)
      .includes(assignment: :assignment_tenures)
  end
end










