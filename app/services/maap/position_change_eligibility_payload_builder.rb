# frozen_string_literal: true

module Maap
  # Builds the LLM user payload for Position-Change Eligibility Consult OG.
  class PositionChangeEligibilityPayloadBuilder
    SHARED_PRIVACY = %w[observed_and_managers public_to_company public_to_world].freeze
    MANAGER_ONLY_PRIVACY = %w[managers_only].freeze
    TEAMMATE_ONLY_PRIVACY = %w[observed_only].freeze

    CRITERION_LABELS = {
      business_need: 'Business need',
      company_aspirational_values_check_in_requirements: 'Values alignment (aspirational values)',
      required_assignment_check_in_requirements: 'Required Assignments',
      unique_to_you_assignment_check_in_requirements: 'Unique-to-You Assignments',
      milestone_requirements: 'Specific Ability Milestones',
      mileage_requirements: 'Ability Milestone Mileage',
      position_check_in_requirements: 'Position Check-ins'
    }.freeze

    Result = Data.define(
      :payload,
      :change_type,
      :manager_private_present,
      :teammate_private_present,
      :units_total
    )

    def self.call(teammate:, position:, organization:)
      new(teammate: teammate, position: position, organization: organization).call
    end

    def initialize(teammate:, position:, organization:)
      @teammate = teammate
      @position = position
      @organization = organization
      @person = teammate.person
      @window_start = 1.year.ago
      @last_position_change_at = last_position_change_at
      @eligibility_report = PositionEligibilityService.new.check_eligibility(teammate, position)
      @relevance = relevance_flags
    end

    def call
      manager_obs = manager_private_observations
      teammate_obs = teammate_private_observations
      manager_private_present = manager_obs.any?
      teammate_private_present = teammate_obs.any?
      units = 1 + (manager_private_present ? 1 : 0) + (teammate_private_present ? 1 : 0)

      sections = [
        { 'title' => 'Context', 'body' => context_section },
        { 'title' => 'Relevant criteria (analyze these; skip others)', 'body' => relevant_criteria_section },
        { 'title' => 'Irrelevant criteria (skip entirely)', 'body' => irrelevant_criteria_section },
        { 'title' => 'Business need / seats', 'body' => business_need_section },
        { 'title' => 'Deterministic eligibility checks', 'body' => eligibility_checks_section },
        { 'title' => 'Assignment check-ins (past year, with carry-forward)', 'body' => assignment_check_ins_section },
        { 'title' => 'Aspiration check-ins (past year, with carry-forward)', 'body' => aspiration_check_ins_section },
        { 'title' => 'Position check-ins (past year, with carry-forward)', 'body' => position_check_ins_section },
        { 'title' => 'Ability milestones attained', 'body' => milestones_section },
        { 'title' => 'Goals (owned by teammate, past year activity)', 'body' => goals_section },
        { 'title' => 'Shared-visible observations (past year)', 'body' => observation_rows(shared_observations) }
      ]

      Result.new(
        payload: { 'sections' => sections },
        change_type: change_type,
        manager_private_present: manager_private_present,
        teammate_private_present: teammate_private_present,
        units_total: units
      )
    end

    def manager_overlay_payload(shared_output_text:)
      {
        'sections' => [
          { 'title' => 'Shared analysis (do not repeat wholesale)', 'body' => shared_output_text.to_s },
          { 'title' => 'Manager-only observations & journals', 'body' => observation_rows(manager_private_observations) },
          { 'title' => 'Manager-private check-in notes (past year)', 'body' => manager_private_notes_section }
        ]
      }
    end

    def teammate_overlay_payload(shared_output_text:)
      {
        'sections' => [
          { 'title' => 'Shared analysis (do not repeat wholesale)', 'body' => shared_output_text.to_s },
          { 'title' => 'Teammate-only observations & journals', 'body' => observation_rows(teammate_private_observations) },
          { 'title' => 'Employee-private check-in notes (past year)', 'body' => employee_private_notes_section }
        ]
      }
    end

    def manager_private_observations
      @manager_private_observations ||= begin
        manager_person_ids = manager_hierarchy_person_ids
        base = observations_for_teammate.where(privacy_level: MANAGER_ONLY_PRIVACY)
        journals = observations_for_teammate
          .journal
          .where(observer_id: manager_person_ids)
        Observation.where(id: base.select(:id)).or(Observation.where(id: journals.select(:id)))
          .includes(:observer, observation_ratings: :rateable)
          .order(observed_at: :desc)
          .limit(80)
          .to_a
      end
    end

    def teammate_private_observations
      @teammate_private_observations ||= begin
        base = observations_for_teammate.where(privacy_level: TEAMMATE_ONLY_PRIVACY)
        journals = observations_for_teammate
          .journal
          .where(observer_id: @person.id)
        Observation.where(id: base.select(:id)).or(Observation.where(id: journals.select(:id)))
          .includes(:observer, observation_ratings: :rateable)
          .order(observed_at: :desc)
          .limit(80)
          .to_a
      end
    end

    private

    def context_section
      {
        'Casual name' => casual_name,
        'Display name' => @person.display_name,
        'Target position (full name)' => @position.display_name,
        'Current position (full name)' => current_position&.display_name || '(none)',
        'Change type' => change_type,
        'Evidence window start' => @window_start.to_date.iso8601,
        'Last position-changing tenure started' => @last_position_change_at&.to_date&.iso8601 || '(unknown)',
        'Weighting note' => weighting_note,
        'Check-in carry-forward rule' => CHECK_IN_CARRY_FORWARD_RULE,
        'Managerial chain (casual names)' => managerial_chain_casual_names
      }
    end

    CHECK_IN_CARRY_FORWARD_RULE =
      'Once a check-in is finalized, its official rating remains in effect for all subsequent months ' \
      'until the next check-in for that same subject is finalized. Example: a "meeting" check-in six ' \
      'months ago with no later finalized check-in counts as six months of meeting expectations. ' \
      'Do not treat the absence of a new monthly check-in as a gap or reset.'.freeze

    def weighting_note
      if @last_position_change_at && @last_position_change_at > @window_start
        "Prefer patterns since #{@last_position_change_at.to_date.iso8601} a little more heavily; still acknowledge earlier evidence in the year window."
      else
        'Use the full past-year window evenly; no mid-window position change detected.'
      end
    end

    def relevant_criteria_section
      list = []
      list << CRITERION_LABELS[:business_need] if @relevance[:business_need]
      list << CRITERION_LABELS[:company_aspirational_values_check_in_requirements] if @relevance[:values]
      list << CRITERION_LABELS[:required_assignment_check_in_requirements] if @relevance[:required_assignments]
      list << CRITERION_LABELS[:unique_to_you_assignment_check_in_requirements] if @relevance[:unique_to_you]
      list << CRITERION_LABELS[:milestone_requirements] if @relevance[:milestones]
      list << CRITERION_LABELS[:mileage_requirements] if @relevance[:mileage]
      list << CRITERION_LABELS[:position_check_in_requirements] if @relevance[:position_check_ins]
      list.presence || ['(none marked relevant)']
    end

    def irrelevant_criteria_section
      skipped = []
      skipped << CRITERION_LABELS[:business_need] unless @relevance[:business_need]
      skipped << CRITERION_LABELS[:unique_to_you_assignment_check_in_requirements] unless @relevance[:unique_to_you]
      skipped << CRITERION_LABELS[:mileage_requirements] unless @relevance[:mileage]
      skipped.presence || ['(none)']
    end

    def business_need_section
      seats = seats_for_position
      open_seats = seats.select(&:open?)
      teammate_seat = teammate_seat_for_position
      maap_managers_path = "/organizations/#{@organization.id}/employees?permission%5B%5D=maap_mgmt"

      {
        'Criterion relevant on page?' => @relevance[:business_need],
        'Seats attached to this title count' => seats.size,
        'Open seats' => open_seats.map(&:display_name).presence || '(none)',
        'Teammate already in a seat for this title?' => teammate_seat.present?,
        'Teammate seat' => teammate_seat&.display_name || '(none)',
        'Guidance when no seat' =>
          if seats.empty?
            "No seat is attached to this position's title. Encourage #{casual_name} and their manager to flesh out whether/when this position will be part of an official seat. If they think this is an error and there is a business need, they should reach out to their manager and someone who can manage MAAP (teammates list filtered to MAAP managers: #{maap_managers_path}) to get OG configured properly."
          else
            'Seat(s) exist for this title; use seat openness / occupancy as context only. Humans decide business need.'
          end
      }
    end

    def eligibility_checks_section
      checks = @eligibility_report[:checks] || []
      checks.map do |check|
        {
          'Key' => check[:key].to_s,
          'Label' => CRITERION_LABELS[check[:key]] || check[:key].to_s.humanize,
          'Status' => check[:status].to_s,
          'Details' => truncate_hash(check[:details])
        }
      end
    end

    def assignment_check_ins_section
      rows = AssignmentCheckIn.closed
        .where(teammate_id: @teammate.id)
        .includes(:assignment)
        .order(:check_in_started_on)
        .to_a

      build_check_in_carry_forward_section(
        rows,
        subject_key: ->(ci) { ci.assignment_id },
        subject_label: ->(ci) { ci.assignment&.title || "(assignment #{ci.assignment_id})" }
      )
    end

    def aspiration_check_ins_section
      rows = AspirationCheckIn.closed
        .where(teammate_id: @teammate.id)
        .includes(:aspiration)
        .order(:check_in_started_on)
        .to_a

      build_check_in_carry_forward_section(
        rows,
        subject_key: ->(ci) { ci.aspiration_id },
        subject_label: ->(ci) { ci.aspiration&.name || "(aspiration #{ci.aspiration_id})" }
      )
    end

    def position_check_ins_section
      rows = PositionCheckIn.closed
        .where(company_teammate: @teammate)
        .order(:check_in_started_on)
        .to_a

      build_check_in_carry_forward_section(
        rows,
        subject_key: ->(_ci) { :position },
        subject_label: ->(_ci) { 'Overall position' }
      )
    end

    def build_check_in_carry_forward_section(rows, subject_key:, subject_label:)
      return '(none)' if rows.empty?

      window_end = Date.current
      grouped = rows.group_by { |ci| subject_key.call(ci) }
      subjects = grouped.filter_map do |_key, check_ins|
        chron = check_ins.sort_by { |ci| [ci.check_in_started_on, ci.id] }
        coverages = []
        chron.each_with_index do |ci, idx|
          next_ci = chron[idx + 1]
          effective_from = ci.check_in_started_on.to_date
          effective_until = if next_ci
                              next_ci.check_in_started_on.to_date - 1.day
                            else
                              window_end
                            end

          # Clip to the evidence window for month counting
          clipped_from = [effective_from, @window_start.to_date].max
          clipped_until = [effective_until, window_end].min
          next if clipped_until < clipped_from
          next if clipped_until < @window_start.to_date

          months = months_inclusive(clipped_from, clipped_until)
          coverages << {
            'Subject' => subject_label.call(ci),
            'Finalized on' => effective_from.iso8601,
            'Official rating' => ci.official_rating,
            'Employee rating' => ci.employee_rating,
            'Manager rating' => ci.manager_rating,
            'Shared notes' => truncate_text(ci.shared_notes),
            'Effective from (in evidence window)' => clipped_from.iso8601,
            'Effective until' => clipped_until.iso8601,
            'Months at this official rating (carry-forward)' => months,
            'Since last position change?' => since_last_change?(effective_from)
          }
        end
        next if coverages.empty?

        {
          'Subject' => subject_label.call(chron.last),
          'Rating periods in evidence window' => coverages
        }
      end

      return '(none overlapping evidence window)' if subjects.empty?

      {
        'Carry-forward rule' => CHECK_IN_CARRY_FORWARD_RULE,
        'Subjects' => subjects
      }
    end

    def months_inclusive(from_date, to_date)
      from = from_date.to_date.beginning_of_month
      to = to_date.to_date.beginning_of_month
      return 0 if to < from

      ((to.year * 12) + to.month) - ((from.year * 12) + from.month) + 1
    end

    def milestones_section
      rows = @teammate.teammate_milestones.includes(:ability).order(attained_at: :desc).limit(60)
      return '(none)' if rows.empty?

      rows.map do |tm|
        {
          'Ability' => tm.ability&.name,
          'Level' => tm.milestone_level,
          'Attained' => tm.attained_at&.to_date&.iso8601,
          'Since last position change?' => since_last_change?(tm.attained_at)
        }
      end
    end

    def goals_section
      goals = Goal.where(owner: @teammate, deleted_at: nil)
        .where('goals.updated_at >= ? OR goals.started_at >= ? OR goals.completed_at >= ?',
               @window_start, @window_start, @window_start)
        .includes(:goal_associations, :goal_check_ins)
        .order(updated_at: :desc)
        .limit(40)

      return '(none)' if goals.empty?

      goals.map do |goal|
        check_ins = goal.goal_check_ins.order(check_in_week_start: :desc).limit(5)
        {
          'Title' => goal.title,
          'Type' => goal.goal_type,
          'Status' => goal.status.to_s,
          'Associations' => goal.goal_associations.map { |ga| "#{ga.associable_type}: #{associable_name(ga)}" }.presence || '(none)',
          'Recent confidence check-ins' => check_ins.map { |c|
            "#{c.check_in_week_start}: #{c.confidence_percentage}% — #{truncate_text(c.confidence_reason, 200)}"
          }.presence || '(none)'
        }
      end
    end

    def manager_private_notes_section
      notes_from_check_ins(:manager_private_notes)
    end

    def employee_private_notes_section
      notes_from_check_ins(:employee_private_notes)
    end

    def notes_from_check_ins(field)
      items = []
      AssignmentCheckIn.closed.where(teammate_id: @teammate.id)
        .where(check_in_started_on: @window_start.to_date..)
        .includes(:assignment).find_each do |ci|
        text = ci.public_send(field)
        next if text.blank?

        items << {
          'Type' => 'Assignment check-in',
          'Subject' => ci.assignment&.title,
          'Date' => ci.check_in_started_on&.iso8601,
          'Notes' => truncate_text(text, 800)
        }
      end
      AspirationCheckIn.closed.where(teammate_id: @teammate.id)
        .where(check_in_started_on: @window_start.to_date..)
        .includes(:aspiration).find_each do |ci|
        text = ci.public_send(field)
        next if text.blank?

        items << {
          'Type' => 'Aspiration check-in',
          'Subject' => ci.aspiration&.name,
          'Date' => ci.check_in_started_on&.iso8601,
          'Notes' => truncate_text(text, 800)
        }
      end
      PositionCheckIn.closed.where(company_teammate: @teammate)
        .where(check_in_started_on: @window_start.to_date..)
        .find_each do |ci|
        text = ci.public_send(field)
        next if text.blank?

        items << {
          'Type' => 'Position check-in',
          'Subject' => 'Position',
          'Date' => ci.check_in_started_on&.iso8601,
          'Notes' => truncate_text(text, 800)
        }
      end
      items.presence || '(none)'
    end

    def shared_observations
      observations_for_teammate
        .where(privacy_level: SHARED_PRIVACY)
        .includes(:observer, observation_ratings: :rateable)
        .order(observed_at: :desc)
        .limit(100)
        .to_a
    end

    def observations_for_teammate
      Observation
        .joins(:observees)
        .where(observees: { teammate_id: @teammate.id })
        .where(company_id: company_ids)
        .published
        .not_soft_deleted
        .where(observed_at: @window_start..)
        .distinct
    end

    def observation_rows(observations)
      return '(none)' if observations.blank?

      observations.map do |obs|
        {
          'Date' => obs.observed_at&.to_date&.iso8601,
          'Privacy' => obs.privacy_level,
          'Type' => obs.observation_type,
          'Observer' => obs.observer&.casual_name || obs.observer&.display_name,
          'Story' => truncate_text(obs.story, 600),
          'Ratings' => obs.observation_ratings.map { |r|
            "#{r.rateable_type}: #{rateable_label(r)} → #{r.rating}"
          }.presence || '(none)',
          'Since last position change?' => since_last_change?(obs.observed_at)
        }
      end
    end

    def relevance_flags
      mileage_check = @eligibility_report[:checks]&.find { |c| c[:key] == :mileage_requirements }
      show_mileage = !mileage_zero_percent?(mileage_check)

      required_assignment_ids = @position.required_assignments.pluck(:assignment_id)
      unique_assignments = @teammate.assignment_tenures.active
        .where.not(assignment_id: required_assignment_ids)
        .exists?
      uty_req = unique_to_you_requirements
      position_has_uty = uty_req_positive?(uty_req)

      active_seat = @teammate.employment_tenures.active.where(company: @organization).includes(seat: [:title, :seat_titles]).first&.seat
      show_business_need = active_seat.nil? || !active_seat.includes_title_id?(@position.title_id)

      {
        business_need: show_business_need,
        values: true,
        required_assignments: true,
        unique_to_you: position_has_uty || unique_assignments,
        milestones: true,
        mileage: show_mileage,
        position_check_ins: true
      }
    end

    def unique_to_you_requirements
      record = PositionEligibilityResolver.resolve(@position).record
      return {} unless record

      record.to_eligibility_service_hash['unique_to_you_assignment_check_in_requirements'] || {}
    end

    def uty_req_positive?(requirements)
      meeting = requirements['minimum_percentage_of_assignments_meeting'] || requirements[:minimum_percentage_of_assignments_meeting]
      exceeding = requirements['minimum_percentage_of_assignments_exceeding'] || requirements[:minimum_percentage_of_assignments_exceeding]
      meeting.to_f.positive? || exceeding.to_f.positive?
    end

    def mileage_zero_percent?(mileage_check)
      return false if mileage_check.blank? || mileage_check[:status] == :not_configured

      details = mileage_check[:details] || {}
      threshold_type = details[:threshold_type] || details['threshold_type']
      threshold_value = details[:threshold_value] || details['threshold_value']
      threshold_type.to_s == 'percentage' && !threshold_value.nil? && threshold_value.to_i.zero?
    end

    def change_type
      @change_type ||= begin
        current = current_position
        if current.nil?
          'title_change'
        elsif current.id == @position.id
          'same_position'
        elsif current.title_id == @position.title_id
          'intra_title'
        else
          'title_change'
        end
      end
    end

    def current_position
      @current_position ||= @teammate.active_employment_tenure&.position
    end

    def last_position_change_at
      tenures = @teammate.employment_tenures.order(started_at: :asc).to_a
      return tenures.last&.started_at if tenures.size <= 1

      previous = nil
      last_change = tenures.first&.started_at
      tenures.each do |tenure|
        if previous && previous.position_id != tenure.position_id
          last_change = tenure.started_at
        end
        previous = tenure
      end
      last_change
    end

    def since_last_change?(time)
      return false if time.blank? || @last_position_change_at.blank?

      time.to_time >= @last_position_change_at
    end

    def casual_name
      @casual_name ||= @person.casual_name.presence || @person.display_name
    end

    def managerial_chain_casual_names
      managers = ManagerialHierarchyQuery.new(person: @person, organization: @organization).call
      managers.filter_map do |m|
        ct = CompanyTeammate.find_by(person_id: m[:person_id], organization_id: @organization.id)
        next unless ct

        ct.person.casual_name.presence || ct.person.display_name
      end
    end

    def manager_hierarchy_person_ids
      ManagerialHierarchyQuery.new(person: @person, organization: @organization).call.map { |m| m[:person_id] }
    end

    def seats_for_position
      Seat.active
        .left_joins(:seat_titles)
        .where('seats.title_id = :title_id OR seat_titles.title_id = :title_id', title_id: @position.title_id)
        .distinct
        .ordered
        .to_a
    end

    def teammate_seat_for_position
      @teammate.employment_tenures
        .active
        .left_joins(seat: :seat_titles)
        .where('seats.title_id = :title_id OR seat_titles.title_id = :title_id', title_id: @position.title_id)
        .distinct
        .first
        &.seat
    end

    def company_ids
      @company_ids ||= begin
        root = @organization.root_company || @organization
        root.self_and_descendants.map(&:id)
      end
    end

    def associable_name(goal_association)
      associable = goal_association.associable
      return "(#{goal_association.associable_type} #{goal_association.associable_id})" unless associable

      associable.try(:name) || associable.try(:title) || associable.try(:display_name) || associable.to_s
    end

    def rateable_label(rating)
      rateable = rating.rateable
      return "(#{rating.rateable_type} #{rating.rateable_id})" unless rateable

      rateable.try(:name) || rateable.try(:title) || rateable.to_s
    end

    def truncate_text(text, limit = 400)
      str = text.to_s.strip
      return nil if str.blank?

      str.length > limit ? "#{str[0, limit]}…" : str
    end

    def truncate_hash(obj, depth = 0)
      return obj if depth > 3

      case obj
      when Hash
        obj.transform_values { |v| truncate_hash(v, depth + 1) }
      when Array
        obj.first(30).map { |v| truncate_hash(v, depth + 1) }
      when String
        truncate_text(obj, 300)
      else
        obj
      end
    end
  end
end
