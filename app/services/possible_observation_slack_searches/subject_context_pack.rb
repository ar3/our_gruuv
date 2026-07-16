# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Compact MAAP + goals language for the Slack OGO extractor (subject teammate).
  class SubjectContextPack
    Result = Struct.new(:prompt_text, :catalog, keyword_init: true)
    DESC_LIMIT = 500

    def self.call(...) = new(...).call

    def initialize(teammate:, organization:)
      @teammate = teammate
      @organization = organization
    end

    def call
      catalog = {
        "Assignment" => {},
        "Ability" => {},
        "Aspiration" => {},
        "Goal" => {}
      }
      sections = []

      sections << aspirations_section(catalog)
      sections << assignments_section(catalog)
      sections << abilities_section(catalog)
      sections << goals_section(catalog)

      Result.new(
        prompt_text: sections.compact_blank.join("\n\n"),
        catalog: catalog
      )
    end

    private

    attr_reader :teammate, :organization

    def aspirations_section(catalog)
      aspirations = Aspiration.within_hierarchy(organization).ordered.to_a
      return "ASPIRATIONS:\n(none)" if aspirations.empty?

      lines = aspirations.map do |aspiration|
        catalog["Aspiration"][aspiration.id] = aspiration.name.to_s
        desc = truncate_text(aspiration.description)
        "- [Aspiration id=#{aspiration.id}] #{aspiration.name}\n  #{desc}"
      end
      "ASPIRATIONS (use these exact names/ids when suggesting):\n#{lines.join("\n")}"
    end

    def assignments_section(catalog)
      assignments = relevant_assignments.includes(:assignment_outcomes).to_a
      return "ASSIGNMENTS (outcomes only):\n(none)" if assignments.empty?

      lines = assignments.map do |assignment|
        catalog["Assignment"][assignment.id] = assignment.title.to_s
        outcomes = assignment.assignment_outcomes.ordered.map { |o| truncate_text(o.description) }.compact_blank
        outcome_block =
          if outcomes.empty?
            "  Outcomes: (none listed)"
          else
            "  Outcomes:\n#{outcomes.map { |d| "  - #{d}" }.join("\n")}"
          end
        "- [Assignment id=#{assignment.id}] #{assignment.title}\n#{outcome_block}"
      end
      "ASSIGNMENTS (outcomes only — ignore other assignment fields):\n#{lines.join("\n")}"
    end

    def abilities_section(catalog)
      rows = RelevantAbilitiesQuery.new(teammate: teammate, organization: organization).call
      return "ABILITIES:\n(none)" if rows.empty?

      lines = rows.map do |row|
        ability = row[:ability]
        catalog["Ability"][ability.id] = ability.name.to_s
        desc = truncate_text(ability.description)
        "- [Ability id=#{ability.id}] #{ability.name}\n  #{desc}"
      end
      "ABILITIES:\n#{lines.join("\n")}"
    end

    def goals_section(catalog)
      goals = Goal.active.where(owner: teammate).order(:title).limit(40).to_a
      return "ACTIVE GOALS:\n(none)" if goals.empty?

      lines = goals.map do |goal|
        catalog["Goal"][goal.id] = goal.title.to_s
        desc = truncate_text(goal.description)
        "- [Goal id=#{goal.id}] #{goal.title}\n  #{desc}"
      end
      "ACTIVE GOALS:\n#{lines.join("\n")}"
    end

    def relevant_assignments
      active_tenure = teammate.active_employment_tenure
      relevant_assignment_ids = Set.new

      if active_tenure&.position
        active_tenure.position.required_assignments.each { |pa| relevant_assignment_ids.add(pa.assignment_id) }
      end

      teammate.assignment_tenures
              .active_and_given_energy
              .joins(:assignment)
              .where(assignments: { company: teammate.organization })
              .pluck(:assignment_id)
              .each { |id| relevant_assignment_ids.add(id) }

      Assignment.where(id: relevant_assignment_ids.to_a)
    end

    def truncate_text(value)
      value.to_s.gsub(/\s+/, " ").strip.truncate(DESC_LIMIT)
    end
  end
end
