# frozen_string_literal: true

module JobDescriptionAcknowledgements
  # Current true job description for signing: held assignments with energy,
  # missing required assignments at 0%, print-style ability sentences,
  # required abilities section, and seat labels.
  class Document
    Result = Struct.new(:snapshot, :employment_tenure, :position, keyword_init: true)

    def self.call(teammate:, organization:)
      new(teammate: teammate, organization: organization).call
    end

    def initialize(teammate:, organization:)
      @teammate = teammate
      @organization = organization
    end

    def call
      Result.new(
        snapshot: snapshot,
        employment_tenure: employment_tenure,
        position: position
      )
    end

    private

    def snapshot
      {
        "casual_name" => casual_name,
        "position_id" => position&.id,
        "position_name" => position&.display_name,
        "summary" => position&.combined_summary,
        "seat" => seat_snapshot,
        "required_assignments" => required_rows,
        "optional_assignments" => optional_rows,
        "required_abilities" => required_ability_rows,
        "direct_milestones" => direct_milestone_rows
      }
    end

    def casual_name
      @teammate.person.casual_name.to_s.strip
    end

    def employment_tenure
      @employment_tenure ||= @teammate.employment_tenures
        .where(company: @organization, ended_at: nil)
        .includes(
          seat: [:team, :reports_to_seat, { title: :department }],
          position: [
            :position_level,
            { title: :department },
            { position_abilities: :ability },
            { position_assignments: { assignment: [:assignment_outcomes, { assignment_abilities: :ability }] } }
          ]
        )
        .order(started_at: :desc)
        .first
    end

    def position
      employment_tenure&.position
    end

    def seat
      employment_tenure&.seat
    end

    def seat_snapshot
      if seat.blank?
        return {
          "present" => false,
          "reports_to" => nil,
          "job_classification" => nil,
          "team" => nil,
          "department" => nil,
          "direct_reports" => nil,
          "disclaimer" => nil,
          "work_environment" => nil,
          "physical_requirements" => nil,
          "travel" => nil
        }
      end

      hr = JobDescriptionHrText.for(organization: @organization, title: seat.title || position&.title, seat: seat)
      {
        "present" => true,
        "reports_to" => seat.reports_to_seat&.display_name.presence || "--Not selected--",
        "job_classification" => seat.job_classification.presence || "--Not selected--",
        "team" => seat.team&.display_name.presence || "--Not selected--",
        "department" => seat.title&.department&.display_name.presence || "--Not selected--",
        "direct_reports" => seat.reports.presence || "--Not answered yet--",
        "disclaimer" => hr.disclaimer,
        "work_environment" => hr.work_environment,
        "physical_requirements" => hr.physical_requirements,
        "travel" => hr.travel
      }
    end

    def active_tenures
      @active_tenures ||= @teammate.assignment_tenures
        .active
        .joins(:assignment)
        .where(assignments: { company_id: @organization.id })
        .includes(assignment: [:assignment_outcomes, { assignment_abilities: :ability }])
        .to_a
    end

    def required_position_assignments
      return [] unless position

      position.position_assignments.select(&:required?)
    end

    def required_rows
      held_ids = required_position_assignments.map(&:assignment_id)
      held = active_tenures
        .select { |tenure| held_ids.include?(tenure.assignment_id) }
        .sort_by { |tenure| [-(tenure.anticipated_energy_percentage || 0), tenure.assignment.title.to_s.downcase] }
        .map { |tenure| assignment_row(tenure.assignment, energy: tenure.anticipated_energy_percentage, missing: false, kind: "required") }

      missing = required_position_assignments
        .reject { |position_assignment| active_tenures.any? { |tenure| tenure.assignment_id == position_assignment.assignment_id } }
        .sort_by { |position_assignment| position_assignment.assignment.title.to_s.downcase }
        .map { |position_assignment| assignment_row(position_assignment.assignment, energy: 0, missing: true, kind: "required") }

      held + missing
    end

    def optional_rows
      required_ids = required_position_assignments.map(&:assignment_id)
      active_tenures
        .reject { |tenure| required_ids.include?(tenure.assignment_id) }
        .sort_by { |tenure| [-(tenure.anticipated_energy_percentage || 0), tenure.assignment.title.to_s.downcase] }
        .map { |tenure| assignment_row(tenure.assignment, energy: tenure.anticipated_energy_percentage, missing: false, kind: "optional") }
    end

    def assignment_row(assignment, energy:, missing:, kind:)
      {
        "assignment_id" => assignment.id,
        "assignment_param" => assignment.to_param,
        "title" => assignment.title,
        "kind" => kind,
        "tagline" => assignment.tagline,
        "outcomes" => assignment.assignment_outcomes.map(&:description),
        "energy_percentage" => missing ? 0 : energy,
        "energy_unset" => !missing && energy.nil?,
        "missing" => missing,
        "abilities" => ability_sentence_items(assignment.assignment_abilities)
      }
    end

    def ability_sentence_items(records)
      records.sort_by { |record| [record.milestone_level.to_i, record.ability.name.to_s.downcase] }.map do |record|
        {
          "ability_id" => record.ability_id,
          "ability_param" => record.ability.to_param,
          "ability_name" => record.ability.name,
          "milestone_level" => record.milestone_level.to_i
        }
      end
    end

    def direct_milestone_rows
      return [] unless position

      ability_sentence_items(position.position_abilities)
    end

    def required_ability_rows
      return [] unless position

      structured = structured_requirements_from_position
      return [] if structured.blank?

      abilities = Ability.where(id: structured.keys).index_by(&:id)
      structured.keys.filter_map do |ability_id|
        ability = abilities[ability_id]
        next unless ability

        sources = structured[ability_id][:sources]
        levels = sources.map { |source| source[:level].to_i }.uniq.sort
        {
          "ability_id" => ability.id,
          "ability_param" => ability.to_param,
          "ability_name" => ability.name,
          "description" => ability.description,
          "milestones" => levels.map { |level| required_milestone_row(ability, level, sources) }
        }
      end.sort_by { |row| row["ability_name"].to_s.downcase }
    end

    # Same union as MyGrowthAbilityMilestoneRows, using associations already loaded for the snapshot.
    def structured_requirements_from_position
      grouped = Hash.new { |hash, key| hash[key] = { levels: [], sources: [] } }

      position.position_abilities.each do |position_ability|
        next unless position_ability.ability_id.present? && position_ability.milestone_level.present?

        level = position_ability.milestone_level.to_i
        grouped[position_ability.ability_id][:levels] << level
        grouped[position_ability.ability_id][:sources] << { kind: :direct, level: level, assignment: nil }
      end

      required_position_assignments.each do |position_assignment|
        assignment = position_assignment.assignment
        next unless assignment

        assignment.assignment_abilities.each do |assignment_ability|
          next unless assignment_ability.ability_id.present? && assignment_ability.milestone_level.present?

          level = assignment_ability.milestone_level.to_i
          grouped[assignment_ability.ability_id][:levels] << level
          grouped[assignment_ability.ability_id][:sources] << { kind: :assignment, level: level, assignment: assignment }
        end
      end

      return {} if grouped.empty?

      grouped.transform_values do |data|
        {
          sources: normalize_requirement_sources(data[:sources])
        }
      end
    end

    def normalize_requirement_sources(sources)
      seen = {}
      sources.each_with_object([]) do |source, out|
        key = case source[:kind]
              when :direct then [:direct, source[:level].to_i]
              when :assignment then [:assignment, source[:assignment]&.id, source[:level].to_i]
              end
        next if seen[key]

        seen[key] = true
        out << source
      end
    end

    def required_milestone_row(ability, level, sources)
      assignment_titles = sources
        .select { |source| source[:kind] == :assignment && source[:level].to_i >= level }
        .map { |source| source[:assignment]&.title.presence }
        .compact
        .uniq
      required_directly = sources.any? { |source| source[:kind] == :direct && source[:level].to_i >= level }
      description = ability.milestone_description(level).to_s
      markdown_parts = []
      markdown_parts << description if description.present?
      if assignment_titles.any?
        markdown_parts << "Assignments that require at least this milestone: #{assignment_titles.to_sentence}."
      end
      if required_directly
        markdown_parts << "Also required directly by the position."
      end

      {
        "milestone_level" => level,
        "description" => description,
        "markdown" => markdown_parts.join("\n\n"),
        "assignment_titles" => assignment_titles,
        "required_directly" => required_directly
      }
    end
  end
end
