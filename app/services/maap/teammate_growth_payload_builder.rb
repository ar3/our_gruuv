# frozen_string_literal: true

module Maap
  class TeammateGrowthPayloadBuilder
    def self.call(teammate:, organization:)
      new(teammate: teammate, organization: organization).call
    end

    def initialize(teammate:, organization:)
      @teammate = teammate
      @organization = organization
    end

    def call
      sections = []
      sections << {
        'title' => 'Teammate under review',
        'body' => teammate_identity_section
      }

      sections << {
        'title' => 'Current employment & position',
        'body' => employment_section
      }

      sections << {
        'title' => 'Active assignments',
        'body' => assignments_section
      }

      sections << {
        'title' => 'Demonstrated ability milestones (earned)',
        'body' => milestones_section
      }

      sections << {
        'title' => 'Stated growth direction',
        'body' => growth_direction_section
      }

      sections << {
        'title' => 'Ritual signals (hub snapshot)',
        'body' => ritual_signals_section
      }

      abilities_for_links = []
      assignments_for_links = []
      positions_for_links = []

      @teammate.assignment_tenures.active.includes(assignment: { assignment_abilities: :ability }).each do |tenure|
        assignments_for_links << tenure.assignment
        tenure.assignment&.assignment_abilities&.each { |aa| abilities_for_links << aa.ability }
      end

      et = @teammate.active_employment_tenure
      if et&.position
        positions_for_links << et.position
        et.position.position_abilities.includes(:ability).each { |pa| abilities_for_links << pa.ability }
        et.position.position_assignments.includes(assignment: { assignment_abilities: :ability }).each do |pa|
          assignments_for_links << pa.assignment
          pa.assignment&.assignment_abilities&.each { |aa| abilities_for_links << aa.ability }
        end
      end

      if @teammate.next_goal_position
        positions_for_links << @teammate.next_goal_position
        @teammate.next_goal_position.position_abilities.includes(:ability).each { |pa| abilities_for_links << pa.ability }
      end

      EntityLinkReferenceSection.append_to_sections!(
        sections,
        organization: @organization,
        abilities: abilities_for_links,
        assignments: assignments_for_links,
        positions: positions_for_links.uniq { |p| p.id }
      )

      { 'sections' => sections }
    end

    private

    def teammate_identity_section
      p = @teammate.person
      {
        'Display name' => p&.display_name || '(unknown)',
        'Organization (route context)' => @organization.name,
        'Employment state' => employment_state_label
      }
    end

    def employment_state_label
      return 'Not yet employed (follower)' if @teammate.follower?
      return 'Employed' if @teammate.employed?
      return 'Terminated' if @teammate.terminated?

      'Unknown'
    end

    def employment_section
      et = @teammate.active_employment_tenure
      unless et
        return {
          'Status' => 'No active employment tenure for this organization context.',
          'Note' => 'Growth review may be limited until employment is recorded.'
        }
      end

      pos = et.position
      mgr = et.manager_teammate

      {
        'Position' => pos&.display_name || '(none)',
        'Position summary (truncated)' => truncate_or_none(pos&.combined_summary || pos&.position_summary),
        'Manager teammate' => mgr&.person&.display_name || '(none or self-service)',
        'Started' => et.started_at&.strftime('%Y-%m-%d') || '(unknown)',
        'Seat / company' => et.company&.name || '(unknown)'
      }
    end

    def assignments_section
      tenures = @teammate.assignment_tenures.active.includes(assignment: { assignment_abilities: :ability }).to_a
      return '(none)' if tenures.empty?

      tenures.sort_by { |t| t.assignment&.title.to_s.downcase }.map do |t|
        asg = t.assignment
        next unless asg

        {
          'Assignment' => asg.title,
          'Started' => t.started_at&.strftime('%Y-%m-%d'),
          'Anticipated energy %' => t.anticipated_energy_percentage,
          'Abilities required (milestone level)' =>
            asg.assignment_abilities.includes(:ability).map { |aa| "#{aa.ability.name}: M#{aa.milestone_level}" }
        }
      end.compact
    end

    def milestones_section
      rows = @teammate.teammate_milestones.includes(:ability).order(attained_at: :desc).limit(40)
      return '(none)' if rows.empty?

      rows.map do |tm|
        {
          'Ability' => tm.ability&.name || "(ability #{tm.ability_id})",
          'Milestone level' => tm.milestone_level,
          'Attained on' => tm.attained_at&.strftime('%Y-%m-%d')
        }
      end
    end

    def growth_direction_section
      ng = @teammate.next_goal_position
      goals = Goal.where(owner: @teammate, deleted_at: nil).where.not(started_at: nil).where(completed_at: nil).order(:title).limit(12)

      body = {
        'Next goal position' => ng&.display_name || '(not set)',
        'Next goal position summary (truncated)' => truncate_or_none(ng&.combined_summary || ng&.position_summary)
      }

      if goals.any?
        body['Active goals (titles)'] = goals.map(&:title)
      else
        body['Active goals (titles)'] = '(none in payload window)'
      end

      body
    end

    def ritual_signals_section
      thirty_days_ago = 30.days.ago
      given = Observation
        .where(company: @organization, observer: @teammate.person)
        .where('observed_at >= ?', thirty_days_ago)
        .where.not(published_at: nil)
        .where(deleted_at: nil)
        .count
      received = Observation
        .joins(:observees)
        .where(company: @organization)
        .where(observees: { teammate_id: @teammate.id })
        .where('observed_at >= ?', thirty_days_ago)
        .where.not(published_at: nil)
        .where(deleted_at: nil)
        .count

      {
        'Observations given (30 days, published)' => given,
        'Observations received (30 days, published)' => received,
        'Note' => 'Counts are coarse signals only; they do not measure observation quality.'
      }
    end

    def truncate_or_none(text)
      s = text.to_s.strip
      return '(none)' if s.blank?

      s.truncate(4_000)
    end
  end
end
