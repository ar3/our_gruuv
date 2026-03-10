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

    # Find abilities required by position direct milestone requirements
    position_ability_ids = abilities_from_position_milestones(org_hierarchy)
    relevant_ability_ids.merge(position_ability_ids)

    relevant_ability_ids
  end

  def abilities_from_position_milestones(org_hierarchy)
    active_tenure = @teammate.active_employment_tenure
    return [] unless active_tenure&.position

    active_tenure.position.position_abilities
      .joins(:ability)
      .where(abilities: { company_id: org_hierarchy.pluck(:id) })
      .pluck(:ability_id)
  end

  def abilities_from_milestones(org_hierarchy)
    org_ids = org_hierarchy.pluck(:id)
    @teammate.teammate_milestones
              .joins(:ability)
              .where(abilities: { company_id: org_ids })
              .pluck(:ability_id)
  end

  def abilities_from_active_assignments(org_hierarchy)
    AssignmentAbility
      .joins(assignment: :assignment_tenures)
      .where(assignment_tenures: { teammate_id: @teammate.id, ended_at: nil })
      .where(assignments: { company: org_hierarchy })
      .pluck(:ability_id)
  end

  def build_ability_data(relevant_ability_ids)
    abilities = load_abilities_with_associations(relevant_ability_ids)
    ability_ids = abilities.map(&:id)

    # Batch load to avoid N+1: teammate_milestones, assignment_requirements, position_requirements per ability
    milestones_by_ability_id = preload_milestone_attainments_by_ability(ability_ids)
    assignment_requirements_by_ability_id = preload_assignment_requirements_by_ability(ability_ids)
    position_requirements_by_ability_id = preload_position_requirements_by_ability(ability_ids)

    abilities.map do |ability|
      {
        ability: ability,
        milestone_attainments: milestones_by_ability_id[ability.id] || [],
        assignment_requirements: assignment_requirements_by_ability_id[ability.id] || [],
        position_requirements: position_requirements_by_ability_id[ability.id] || []
      }
    end
  end

  def load_abilities_with_associations(ability_ids)
    Ability.where(id: ability_ids)
           .includes(assignment_abilities: [:assignment], position_abilities: [:position])
           .order(:name)
  end

  def preload_milestone_attainments_by_ability(ability_ids)
    return {} if ability_ids.empty?

    TeammateMilestone
      .where(teammate_id: @teammate.id, ability_id: ability_ids)
      .by_milestone_level
      .includes(:ability, certifying_teammate: :person)
      .group_by(&:ability_id)
  end

  def preload_assignment_requirements_by_ability(ability_ids)
    return {} if ability_ids.empty?

    AssignmentAbility
      .joins(assignment: :assignment_tenures)
      .where(assignment_tenures: { teammate_id: @teammate.id, ended_at: nil })
      .where(ability_id: ability_ids)
      .includes(assignment: :assignment_tenures)
      .group_by(&:ability_id)
  end

  def preload_position_requirements_by_ability(ability_ids)
    active_tenure = @teammate.active_employment_tenure
    return {} unless active_tenure&.position

    active_tenure
      .position
      .position_abilities
      .where(ability_id: ability_ids)
      .by_milestone_level
      .group_by(&:ability_id)
  end
end











