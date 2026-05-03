# frozen_string_literal: true

module Maap
  class PositionClarityPayloadBuilder
    def self.call(position:)
      new(position: position).call
    end

    def initialize(position:)
      @position = position
    end

    def call
      company = @position.company
      siblings = sibling_positions(company)

      sections = []
      sections << {
        'title' => 'Position under review',
        'body' => position_core_hash
      }

      sections << {
        'title' => 'Other positions in scope for overlap checks',
        'body' => siblings.map { |p| sibling_summary(p) }
      }

      sections << {
        'title' => 'Required and suggested assignments on this position',
        'body' => assignment_sections
      }

      sections << {
        'title' => 'Direct ability requirements on this position',
        'body' => position_abilities_section
      }

      sections << {
        'title' => 'Ability requirements implied via linked assignments',
        'body' => assignment_derived_abilities_section
      }

      abilities_for_links = []
      assignments_for_links = []
      abilities_for_links.concat(@position.position_abilities.includes(:ability).map(&:ability))
      @position.position_assignments.includes(assignment: { assignment_abilities: :ability }).each do |pa|
        assignments_for_links << pa.assignment
        pa.assignment&.assignment_abilities&.each do |aa|
          abilities_for_links << aa.ability
        end
      end

      positions_for_links = [@position] + siblings

      EntityLinkReferenceSection.append_to_sections!(
        sections,
        organization: company,
        abilities: abilities_for_links,
        assignments: assignments_for_links,
        positions: positions_for_links
      )

      { 'sections' => sections }
    end

    private

    def sibling_positions(company)
      Position.unarchived
            .joins(:title)
            .where(titles: { company_id: company.id })
            .where.not(id: @position.id)
            .includes(:title, :position_level)
            .order('titles.external_title ASC, position_levels.level ASC')
            .limit(40)
    end

    def position_core_hash
      t = @position.title
      {
        'Display name' => @position.display_name,
        'Title' => t&.external_title || '(none)',
        'Position level' => @position.position_level&.level || '(none)',
        'Department' => t&.department&.display_name || '(none)',
        'Semantic version' => @position.semantic_version.to_s,
        'Combined summary (title + position)' => truncate_or_none(@position.combined_summary),
        'Position summary only' => truncate_or_none(@position.position_summary),
        'Published source URL' => @position.published_url.presence || '(none)',
        'Draft source URL' => @position.draft_url.presence || '(none)'
      }
    end

    def truncate_or_none(text)
      s = text.to_s.strip
      return '(none)' if s.blank?

      s.truncate(4_000)
    end

    def sibling_summary(p)
      {
        'Display name' => p.display_name,
        'Title' => p.title&.external_title || '(none)',
        'Level' => p.position_level&.level || '(none)'
      }
    end

    def assignment_sections
      pas = @position.position_assignments.includes(:assignment).to_a
      return '(none)' if pas.empty?

      pas.sort_by { |pa| [pa.assignment_type == 'required' ? 0 : 1, pa.assignment&.title.to_s.downcase] }.map do |pa|
        asg = pa.assignment
        {
          'Assignment' => asg&.title || "(missing #{pa.assignment_id})",
          'Link type' => pa.assignment_type,
          'Energy' => pa.energy_percentage_suffix.presence || pa.energy_range_display.presence || '(none)',
          'Assignment tagline' => asg&.tagline.to_s.truncate(300).presence || '(none)'
        }
      end
    end

    def position_abilities_section
      list = @position.position_abilities.includes(:ability).to_a
      return '(none)' if list.empty?

      roman = %w[I II III IV V]

      list.sort_by { |pa| [pa.ability.name.to_s.downcase] }.map do |pa|
        ab = pa.ability
        milestone_rubric = {}
        (1..5).each do |level|
          label = "Milestone #{level} (#{roman[level - 1]})"
          text = ab.send("milestone_#{level}_description").to_s.strip
          milestone_rubric[label] = text.presence || '(not defined)'
        end

        {
          'Ability' => ab.name,
          'Required milestone on position' => "Milestone #{pa.milestone_level} (M#{pa.milestone_level})",
          'Ability description' => ab.description.to_s.truncate(400),
          'Milestone rubric for this ability (I–V)' => milestone_rubric
        }
      end
    end

    def assignment_derived_abilities_section
      pas = @position.position_assignments.includes(assignment: { assignment_abilities: :ability }).to_a
      lines = []
      pas.each do |pa|
        asg = pa.assignment
        next unless asg

        aas = asg.assignment_abilities.includes(:ability).to_a
        next if aas.empty?

        lines << {
          'Via assignment' => "#{asg.title} (#{pa.assignment_type})",
          'Ability milestones required by that assignment' =>
            aas.sort_by { |aa| aa.ability.name.to_s.downcase }.map do |aa|
              "#{aa.ability.name}: Milestone #{aa.milestone_level}"
            end
        }
      end
      return '(none)' if lines.empty?

      lines
    end
  end
end
