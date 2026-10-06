# frozen_string_literal: true

module Observations
  # Assignments / Abilities / Values the observee(s) currently carry — same intersection
  # the OGO form uses when attaching rateables. Not the org-wide catalog.
  class OgoConsultCatalog
    Entry = Data.define(:rateable_type, :id, :name)

    def self.call(observation:)
      new(observation: observation).call
    end

    def initialize(observation:)
      @observation = observation
    end

    def call
      teammates = current_observee_teammates
      assignment_ids, ability_ids = intersection_rateable_ids(teammates)
      aspirations = company_aspirations

      assignments = Assignment.unarchived.where(id: assignment_ids, company: company_scope).ordered
      abilities = Ability.unarchived.where(id: ability_ids, company_id: org_ids).order(:name)

      entries = []
      assignments.each { |a| entries << Entry.new("Assignment", a.id, a.title.to_s) }
      abilities.each { |a| entries << Entry.new("Ability", a.id, a.name.to_s) }
      aspirations.each { |a| entries << Entry.new("Aspiration", a.id, a.name.to_s) }
      entries
    end

    def index_by_key
      call.index_by { |e| "#{e.rateable_type}:#{e.id}" }
    end

    private

    def current_observee_teammates
      observees = if @observation.persisted?
                    @observation.observees.includes(:company_teammate).to_a
                  else
                    @observation.observees.select { |o| o.teammate_id.present? }
                  end

      observees.filter_map do |observee|
        observee.company_teammate || CompanyTeammate.find_by(id: observee.teammate_id)
      end
    end

    def intersection_rateable_ids(teammates)
      return [[], []] if teammates.empty?

      assignment_sets = teammates.map { |tm| active_assignment_ids_for(tm).to_set }
      ability_sets = teammates.map { |tm| relevant_ability_ids_for(tm).to_set }

      [
        assignment_sets.reduce(&:intersection).to_a,
        ability_sets.reduce(&:intersection).to_a
      ]
    end

    def active_assignment_ids_for(teammate)
      teammate.assignment_tenures
              .active_and_given_energy
              .joins(:assignment)
              .where(assignments: { company: @observation.company })
              .pluck(:assignment_id)
    end

    def relevant_ability_ids_for(teammate)
      ids = Set.new
      org_ids_list = org_ids

      active_tenure = teammate.active_employment_tenure
      if active_tenure&.position
        position = active_tenure.position
        position.required_assignments
          .joins(assignment: { assignment_abilities: :ability })
          .where(abilities: { company_id: org_ids_list })
          .pluck("assignment_abilities.ability_id")
          .each { |id| ids.add(id) }
        position.position_abilities
          .joins(:ability)
          .where(abilities: { company_id: org_ids_list })
          .pluck(:ability_id)
          .each { |id| ids.add(id) }
      end

      teammate.assignment_tenures
        .active_and_given_energy
        .joins(assignment: :assignment_abilities)
        .where(assignments: { company_id: org_ids_list })
        .pluck("assignment_abilities.ability_id")
        .each { |id| ids.add(id) }

      ids
    end

    def company_aspirations
      root = @observation.company.root_company || @observation.company
      root.aspirations.where(department_id: nil).ordered
    end

    def company_scope
      @observation.company
    end

    def org_ids
      @org_ids ||= @observation.company.self_and_descendants.pluck(:id)
    end
  end
end
