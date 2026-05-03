# frozen_string_literal: true

module Maap
  class AbilityClarityPayloadBuilder
    def self.call(ability:)
      new(ability: ability).call
    end

    def initialize(ability:)
      @ability = ability
    end

    def call
      company = @ability.company
      siblings = Ability.unarchived.for_company(company).where.not(id: @ability.id).includes(:department).order(:name).limit(40)
      if @ability.department_id.present?
        siblings = siblings.where(department_id: [@ability.department_id, nil])
      end

      sections = []
      sections << {
        'title' => 'Ability under review',
        'body' => ability_core_hash
      }

      sections << {
        'title' => 'Other abilities in scope for overlap checks',
        'body' => siblings.map { |a| sibling_summary(a) }
      }

      sections << {
        'title' => 'Assignments that require this ability',
        'body' => assignment_sections
      }

      sections << {
        'title' => 'Positions that require this ability',
        'body' => position_sections
      }

      assignment_records = @ability.assignment_abilities.includes(:assignment).map(&:assignment)
      position_records = @ability.position_abilities.includes(:position).map(&:position)
      EntityLinkReferenceSection.append_to_sections!(
        sections,
        organization: company,
        abilities: [@ability] + siblings.to_a,
        assignments: assignment_records,
        positions: position_records
      )

      { 'sections' => sections }
    end

    private

    def ability_core_hash
      h = {
        'Name' => @ability.name,
        'Description' => @ability.description.to_s.strip.presence || '(none)',
        'Department' => @ability.department&.display_name || '(none)',
        'Semantic version' => @ability.semantic_version.to_s
      }
      (1..5).each do |level|
        key = "Milestone #{level} (#{roman(level)})"
        h[key] = @ability.send("milestone_#{level}_description").to_s.strip.presence || '(not defined)'
      end
      h
    end

    def roman(level)
      %w[I II III IV V][level - 1]
    end

    def sibling_summary(a)
      {
        'Name' => a.name,
        'Department' => a.department&.display_name || '(none)',
        'Summary' => a.description.to_s.truncate(400)
      }
    end

    def assignment_sections
      list = @ability.assignment_abilities.includes(assignment: :assignment_outcomes).sort_by { |aa| aa.assignment.title.to_s.downcase }
      return '(none)' if list.empty?

      list.map do |aa|
        asg = aa.assignment
        outcomes = asg.assignment_outcomes.ordered.map(&:description)
        {
          'Assignment' => asg.title,
          'Required milestone' => "Milestone #{aa.milestone_level}",
          'Outcomes' => outcomes.presence || '(none listed)'
        }
      end
    end

    def position_sections
      list = @ability.position_abilities.includes(position: { title: :department }).sort_by { |pa| pa.position.display_name.to_s.downcase }
      return '(none)' if list.empty?

      list.map do |pa|
        pos = pa.position
        {
          'Position' => pos.display_name,
          'Required milestone' => "Milestone #{pa.milestone_level}"
        }
      end
    end
  end
end
