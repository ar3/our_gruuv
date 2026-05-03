# frozen_string_literal: true

module Maap
  class AssignmentClarityPayloadBuilder
    def self.call(assignment:)
      new(assignment: assignment).call
    end

    def initialize(assignment:)
      @assignment = assignment
    end

    def call
      company = @assignment.company
      siblings = Assignment.unarchived.for_company(company).where.not(id: @assignment.id).includes(:department).order(:title).limit(40)
      if @assignment.department_id.present?
        siblings = siblings.where(department_id: [@assignment.department_id, nil])
      end

      sections = []
      sections << {
        'title' => 'Assignment under review',
        'body' => assignment_core_hash
      }

      sections << {
        'title' => 'Outcomes',
        'body' => outcomes_body
      }

      sections << {
        'title' => 'Other assignments in scope for overlap checks',
        'body' => siblings.map { |a| sibling_summary(a) }
      }

      sections << {
        'title' => 'Consumer assignments (downstream)',
        'body' => consumer_supplier_section(:consumer)
      }

      sections << {
        'title' => 'Supplier assignments (upstream)',
        'body' => consumer_supplier_section(:supplier)
      }

      sections << {
        'title' => 'Positions linked to this assignment',
        'body' => position_sections
      }

      sections << {
        'title' => 'Abilities required for this assignment',
        'body' => abilities_section
      }

      siblings_arr = siblings.to_a
      assignment_link_list =
        ([@assignment] + siblings_arr + @assignment.consumer_assignments.to_a + @assignment.supplier_assignments.to_a)
        .compact
        .uniq { |a| a.id }
      ability_link_list = @assignment.assignment_abilities.includes(:ability).map(&:ability)
      position_link_list = @assignment.position_assignments.includes(:position).map(&:position)

      EntityLinkReferenceSection.append_to_sections!(
        sections,
        organization: company,
        abilities: ability_link_list,
        assignments: assignment_link_list,
        positions: position_link_list
      )

      { 'sections' => sections }
    end

    private

    def assignment_core_hash
      h = {
        'Title' => @assignment.title,
        'Tagline' => @assignment.tagline.to_s.strip.presence || '(none)',
        'Department' => @assignment.department&.display_name || '(none)',
        'Semantic version' => @assignment.semantic_version.to_s,
        'Required activities' => truncate_or_none(@assignment.required_activities),
        'Handbook excerpt' => truncate_or_none(@assignment.handbook)
      }
      h['Published source URL'] = @assignment.published_url.presence || '(none)'
      h['Draft source URL'] = @assignment.draft_url.presence || '(none)'
      h
    end

    def truncate_or_none(text)
      s = text.to_s.strip
      return '(none)' if s.blank?

      s.truncate(2_000)
    end

    def outcomes_body
      outcomes = @assignment.assignment_outcomes.ordered
      return '(none defined)' if outcomes.empty?

      outcomes.map do |o|
        {
          'Type' => o.outcome_type,
          'Description' => o.description.to_s.truncate(1_200),
          'Progress report URL' => o.progress_report_url.presence || '(none)',
          'Who to ask (management)' => o.management_relationship_filter.presence || '(any)',
          'Who to ask (team)' => o.team_relationship_filter.presence || '(any)',
          'Consumer assignment filter' => o.consumer_assignment_filter.presence || '(any)'
        }
      end
    end

    def sibling_summary(a)
      {
        'Title' => a.title,
        'Department' => a.department&.display_name || '(none)',
        'Tagline' => a.tagline.to_s.truncate(400)
      }
    end

    def consumer_supplier_section(kind)
      list =
        case kind
        when :consumer
          @assignment.consumer_assignments.includes(:department).order(:title)
        when :supplier
          @assignment.supplier_assignments.includes(:department).order(:title)
        end
      return '(none)' if list.blank?

      list.map do |a|
        {
          'Title' => a.title,
          'Department' => a.department&.display_name || '(none)',
          'Tagline' => a.tagline.to_s.truncate(300)
        }
      end
    end

    def position_sections
      list = @assignment.position_assignments.includes(position: [:title, :position_level]).to_a
      return '(none)' if list.empty?

      list.sort_by { |pa| [pa.assignment_type == 'required' ? 0 : 1, pa.position.display_name.to_s.downcase] }.map do |pa|
        pos = pa.position
        {
          'Position' => pos.display_name,
          'Link type' => pa.assignment_type,
          'Energy note' => pa.energy_percentage_suffix.presence || '(none)'
        }
      end
    end

    def abilities_section
      list = @assignment.assignment_abilities.includes(:ability).to_a
      return '(none)' if list.empty?

      roman = %w[I II III IV V]

      list.sort_by { |aa| [aa.ability.name.to_s.downcase] }.map do |aa|
        ab = aa.ability
        milestone_rubric = {}
        (1..5).each do |level|
          label = "Milestone #{level} (#{roman[level - 1]})"
          text = ab.send("milestone_#{level}_description").to_s.strip
          milestone_rubric[label] = text.presence || '(not defined)'
        end

        {
          'Ability' => ab.name,
          'Required milestone for this assignment' => "Milestone #{aa.milestone_level} (same as M#{aa.milestone_level})",
          'Ability description (summary)' => ab.description.to_s.truncate(400),
          'Milestone rubric for this ability (I–V)' => milestone_rubric
        }
      end
    end
  end
end
