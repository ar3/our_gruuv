class Organizations::EligibilityRequirementsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_selectable_teammates, only: [:index, :show]
  before_action :set_positions, only: [:index, :show]
  before_action :set_position, only: [:show]
  before_action :set_teammate, only: [:show]

  def index
    authorize :eligibility_requirement, :index?

    if params[:position_id].present?
      redirect_to organization_eligibility_requirement_path(
        organization,
        params[:position_id],
        teammate_id: params[:teammate_id]
      )
    end
  end

  def show
    authorize :eligibility_requirement, :show?

    unless teammate_allowed?(@teammate)
      flash[:alert] = "You don't have access to that teammate."
      redirect_to organization_eligibility_requirements_path(organization)
      return
    end

    @eligibility_report = PositionEligibilityService.new.check_eligibility(@teammate, @position)
    load_requirement_lists
  end

  private

  def set_positions
    @positions = Position.for_company(organization).ordered
  end

  def set_position
    @position = Position.find_by_param(params[:id])
  end

  def set_teammate
    teammate_id = params[:teammate_id].presence || current_company_teammate&.id
    @teammate = CompanyTeammate.find(teammate_id)
  end

  def set_selectable_teammates
    @selectable_teammates = selectable_teammates
  end

  def load_requirement_lists
    @required_assignments = @position.required_assignments.includes(:assignment).map(&:assignment)
    @unique_assignments = unique_to_you_assignments(@teammate, @position)

    @required_abilities = @required_assignments.flat_map do |assignment|
      assignment.assignment_abilities.includes(:ability).map(&:ability)
    end.uniq

    @unique_abilities = @unique_assignments.flat_map do |assignment|
      assignment.assignment_abilities.includes(:ability).map(&:ability)
    end.uniq

    position_company = @position.company
    @company_aspirations = Aspiration.for_company(position_company).ordered

    # Aspirational values table: one row per value with 12-month teammate status
    @aspirational_values_monthly_status = aspirational_values_monthly_status(@teammate, @company_aspirations.to_a)
    @aspirational_values_table_rows = build_aspirational_values_table_rows
    @aspirational_values_summary = build_aspirational_values_summary

    # Required assignments table: one row per assignment with 12-month teammate status
    @required_assignments_monthly_status = assignment_monthly_status(@teammate, @required_assignments)
    required_check = @eligibility_report[:checks].find { |c| c[:key] == :required_assignment_check_in_requirements }
    @required_assignments_summary = build_required_assignments_summary

    # Unique-to-you assignments: same table structure as required
    @unique_assignments_monthly_status = assignment_monthly_status(@teammate, @unique_assignments)
    unique_check = @eligibility_report[:checks].find { |c| c[:key] == :unique_to_you_assignment_check_in_requirements }
    @unique_assignments_summary = build_check_in_requirements_summary(unique_check, @unique_assignments.map(&:id), @unique_assignments_monthly_status)

    # Per-section aspirational summary (company only)
    company_asp_check = @eligibility_report[:checks].find { |c| c[:key] == :company_aspirational_values_check_in_requirements }
    company_aspiration_ids = @aspirational_values_table_rows.select { |r| r[:section] == 'company' }.map { |r| r[:aspiration].id }
    @company_aspirational_values_summary = build_check_in_requirements_summary(company_asp_check, company_aspiration_ids, @aspirational_values_monthly_status)

    # 3-level eligibility result (row categories + summary) for each section
    @company_aspirational_values_eligibility_result = build_check_in_eligibility_result(company_asp_check, company_aspiration_ids, @aspirational_values_monthly_status)
    @required_assignments_eligibility_result = build_check_in_eligibility_result(required_check, @required_assignments.map(&:id), @required_assignments_monthly_status)
    @unique_assignments_eligibility_result = build_check_in_eligibility_result(unique_check, @unique_assignments.map(&:id), @unique_assignments_monthly_status)

    # Collapsible summary: sentences per check and abilities with max milestone required
    @eligibility_requirements_sentences = build_eligibility_requirements_sentences
    @ability_milestone_requirements = build_ability_milestone_requirements
    @milestone_table_rows = build_milestone_table_rows

    # Milestone Mileage: earned addends (teammate's milestones) and required addends (position + required assignments)
    @mileage_earned_addends = build_mileage_earned_addends
    @mileage_required_addends = build_mileage_required_addends

    # Section (1): Managerial hierarchy for footer (teammate + managers with company_teammate for links)
    @managerial_hierarchy_for_display = build_managerial_hierarchy_for_display

    # Section (2): Business need — seats for this position's title, occupants, and whether teammate is in one or open exists
    @seats_for_position = @position.title.seats.active.ordered
    @open_seats_for_position = @seats_for_position.select(&:open?)
    @teammate_in_seat_for_position = @teammate.employment_tenures.active.joins(:seat).where(seats: { title_id: @position.title_id }).first&.seat
    filled_seat_ids = @seats_for_position.select(&:filled?).map(&:id)
    @seat_occupant_by_seat_id = filled_seat_ids.any? ? EmploymentTenure.active.where(seat_id: filled_seat_ids).includes(:company_teammate).index_by(&:seat_id) : {}
    @business_need_eligible = @teammate_in_seat_for_position.present? || @open_seats_for_position.any?

    # Section (8): Position check-in requirements — monthly status (one row) and eligibility result
    pos_check = @eligibility_report[:checks].find { |c| c[:key] == :position_check_in_requirements }
    if pos_check.present? && pos_check[:status] != :not_configured
      @position_check_in_monthly_status_by_row_id = build_position_check_in_monthly_status(pos_check)
      @position_check_in_eligibility_result = build_position_check_in_eligibility_result(pos_check)
    else
      @position_check_in_monthly_status_by_row_id = nil
      @position_check_in_eligibility_result = nil
    end
  end

  # Array of sentence strings for each configured eligibility check (for collapsible summary).
  def build_eligibility_requirements_sentences
    return [] unless @eligibility_report && @eligibility_report[:checks]

    @eligibility_report[:checks].filter_map do |check|
      helpers.format_eligibility_check_sentence(check)
    end
  end

  # Array of { ability:, minimum_milestone_level: } for abilities that have a milestone requirement
  # (from position direct + required assignments), with max level per ability.
  def build_ability_milestone_requirements
    return [] unless @position

    levels_by_ability_id = {}
    @position.position_abilities.each do |pa|
      levels_by_ability_id[pa.ability_id] = [levels_by_ability_id[pa.ability_id], pa.milestone_level].compact.max
    end
    @required_assignments.each do |assignment|
      assignment.assignment_abilities.each do |aa|
        levels_by_ability_id[aa.ability_id] = [levels_by_ability_id[aa.ability_id], aa.milestone_level].compact.max
      end
    end

    return [] if levels_by_ability_id.empty?

    abilities = Ability.where(id: levels_by_ability_id.keys).index_by(&:id)
    levels_by_ability_id.keys.filter_map { |id| abilities[id] ? { ability: abilities[id], minimum_milestone_level: levels_by_ability_id[id] } : nil }.sort_by { |h| h[:ability].name }
  end

  # Rows for the Milestones table: one per ability with requirement lines, teammate milestone, and pass/fail.
  # Each row: { ability:, requirement_lines: [ { source_name:, milestone_level: }, ... ], teammate_milestone: (TeammateMilestone or nil), passed: Boolean }
  def build_milestone_table_rows
    return [] unless @position && @teammate

    milestones_check = @eligibility_report[:checks]&.find { |c| c[:key] == :milestone_requirements }
    requirements_by_ability = (milestones_check&.dig(:details, :requirements) || []).group_by { |r| r[:ability_id] }

    ability_ids = requirements_by_ability.keys.uniq
    return [] if ability_ids.empty?

    abilities = Ability.where(id: ability_ids).index_by(&:id)
    all_teammate_milestones = TeammateMilestone
      .where(company_teammate: @teammate, ability_id: ability_ids)
      .order(milestone_level: :desc, attained_at: :desc)
    # First per ability = highest level (index_by would keep last, which is lowest after ordering desc)
    teammate_highest_by_ability = all_teammate_milestones.group_by(&:ability_id).transform_values(&:first)
    attained_levels_by_ability = all_teammate_milestones.group_by(&:ability_id).transform_values { |ms| ms.map(&:milestone_level).uniq }

    ability_ids.filter_map do |ability_id|
      ability = abilities[ability_id]
      next unless ability

      requirement_lines = []
      @position.position_abilities.where(ability_id: ability_id).each do |pa|
        requirement_lines << { source_name: "Position", milestone_level: pa.milestone_level }
      end
      @required_assignments.each do |assignment|
        assignment.assignment_abilities.where(ability_id: ability_id).each do |aa|
          requirement_lines << { source_name: assignment.title, milestone_level: aa.milestone_level }
        end
      end

      reqs = requirements_by_ability[ability_id] || []
      passed = reqs.any? && reqs.all? { |r| r[:passed] }
      teammate_milestone = teammate_highest_by_ability[ability_id]
      attained_levels = attained_levels_by_ability[ability_id] || []

      {
        ability: ability,
        requirement_lines: requirement_lines,
        teammate_milestone: teammate_milestone,
        attained_levels: attained_levels,
        passed: passed
      }
    end.sort_by { |row| row[:ability].name }
  end

  # For Milestone Mileage: one row per ability with grouped milestones. Each addend: ability_name, levels (e.g. [1,2,3]), points (cumulative).
  # Display in view: "<highest level display> <ability name> – Milestone 1, 2, & 3".
  def build_mileage_earned_addends
    return { addends: [], total: 0 } unless @teammate

    mileage_service = MilestoneMileageService.new
    milestones = @teammate.teammate_milestones.includes(:ability).order(:milestone_level, :attained_at)
    by_ability = milestones.group_by { |m| [m.ability_id, m.ability.name] }
    addends = by_ability.map do |(_ability_id, ability_name), group|
      levels = group.map(&:milestone_level).sort.uniq
      points = group.sum { |m| mileage_service.milestone_points(m.milestone_level) }
      { ability_name: ability_name, levels: levels, points: points }
    end.sort_by { |a| a[:ability_name] }
    { addends: addends, total: mileage_service.total_mileage_for(@teammate) }
  end

  # For Milestone Mileage: one row per ability with highest required level; points = cumulative (1 through that level).
  # Display: "<highest level display> <ability name> – Milestone 1, 2, & 3" (out to highest required).
  def build_mileage_required_addends
    return { addends: [], total: 0 } unless @position

    mileage_service = MilestoneMileageService.new
    max_level_by_ability = {} # ability_id => { name:, level: }

    @position.position_abilities.includes(:ability).each do |pa|
      id = pa.ability_id
      if max_level_by_ability[id].nil? || pa.milestone_level > max_level_by_ability[id][:level]
        max_level_by_ability[id] = { name: pa.ability.name, level: pa.milestone_level }
      end
    end
    @position.required_assignments.includes(assignment: :assignment_abilities).each do |position_assignment|
      position_assignment.assignment.assignment_abilities.includes(:ability).each do |aa|
        id = aa.ability_id
        if max_level_by_ability[id].nil? || aa.milestone_level > max_level_by_ability[id][:level]
          max_level_by_ability[id] = { name: aa.ability.name, level: aa.milestone_level }
        end
      end
    end

    addends = max_level_by_ability.values.map do |info|
      level = info[:level]
      levels = (1..level).to_a
      { ability_name: info[:name], levels: levels, points: mileage_service.points_through_milestone(level) }
    end.sort_by { |a| a[:ability_name] }
    total = addends.sum { |a| a[:points] }
    { addends: addends, total: total }
  end

  # Returns hash: aspiration_id => [ { month: Date, status: :exceeding|:meeting|:working_to_meet|:none, actual: Boolean }, ... ]
  # (12 months, oldest to newest). Rating in a month carries forward to future months until the next check-in.
  # actual: true when the rating was finalized in that month; false when it's carried from a prior month.
  def aspirational_values_monthly_status(teammate, aspirations)
    return {} if aspirations.blank?

    aspiration_ids = aspirations.map(&:id)
    start_month = 12.months.ago.beginning_of_month.to_date
    end_month = 1.month.ago.end_of_month.to_date

    check_ins = AspirationCheckIn.closed
      .where(teammate_id: teammate.id, aspiration_id: aspiration_ids)
      .where(check_in_started_on: start_month..end_month)
      .pluck(:aspiration_id, :check_in_started_on, :official_rating)

    # Group by (aspiration_id, month): keep best rating and the check-in date that produced it
    rating_order = { 'exceeding' => 3, 'meeting' => 2, 'working_to_meet' => 1 }
    by_aspiration_and_month = check_ins.each_with_object(Hash.new { |h, k| h[k] = nil }) do |(aid, started_on, rating), h|
      month = started_on.beginning_of_month.to_date
      key = [aid, month]
      next if rating.blank?
      level = rating_order[rating.to_s]
      current = h[key]
      if level && (current.nil? || (rating_order[current[:rating]] || 0) < level)
        h[key] = { rating: rating.to_s, check_in_date: started_on }
      end
    end

    # Per aspiration: sorted list of [month, rating, check_in_date] for months that have a check-in
    check_in_months_by_aspiration = aspiration_ids.each_with_object({}) do |aid, out|
      out[aid] = by_aspiration_and_month.select { |(a, _), v| a == aid && v.present? }
        .map { |(_, m), v| [m, v[:rating], v[:check_in_date]] }
        .sort_by(&:first)
    end

    # Build 12 months (oldest to newest)
    months = 12.times.map { |i| (start_month + i.months).beginning_of_month.to_date }

    aspiration_ids.each_with_object({}) do |aid, out|
      pairs = check_in_months_by_aspiration[aid] || []
      out[aid] = months.map do |month|
        # Most recent check-in month <= this month (rating carries forward)
        effective_pair = pairs.select { |m, _, _| m <= month }.last
        status = effective_pair ? effective_pair[1].to_sym : :none
        actual = effective_pair && effective_pair[0] == month
        source_check_in_date = effective_pair ? effective_pair[2] : nil
        {
          month: month,
          status: status,
          actual: actual,
          source_check_in_date: source_check_in_date
        }
      end
    end
  end

  # Rows for aspirational values table: [ { aspiration:, section: 'company' }, ... ]
  def build_aspirational_values_table_rows
    @company_aspirations.map { |a| { aspiration: a, section: 'company' } }
  end

  # Returns hash: assignment_id => [ { month:, status:, actual:, source_check_in_date: }, ... ] (12 months, same structure as aspirations).
  def assignment_monthly_status(teammate, assignments)
    return {} if assignments.blank?

    assignment_ids = assignments.map(&:id)
    start_month = 12.months.ago.beginning_of_month.to_date
    end_month = 1.month.ago.end_of_month.to_date

    check_ins = AssignmentCheckIn.closed
      .where(teammate_id: teammate.id, assignment_id: assignment_ids)
      .where(check_in_started_on: start_month..end_month)
      .pluck(:assignment_id, :check_in_started_on, :official_rating)

    rating_order = { 'exceeding' => 3, 'meeting' => 2, 'working_to_meet' => 1 }
    by_assignment_and_month = check_ins.each_with_object(Hash.new { |h, k| h[k] = nil }) do |(aid, started_on, rating), h|
      month = started_on.beginning_of_month.to_date
      key = [aid, month]
      next if rating.blank?
      level = rating_order[rating.to_s]
      current = h[key]
      if level && (current.nil? || (rating_order[current[:rating]] || 0) < level)
        h[key] = { rating: rating.to_s, check_in_date: started_on }
      end
    end

    check_in_months_by_assignment = assignment_ids.each_with_object({}) do |aid, out|
      out[aid] = by_assignment_and_month.select { |(a, _), v| a == aid && v.present? }
        .map { |(_, m), v| [m, v[:rating], v[:check_in_date]] }
        .sort_by(&:first)
    end

    months = 12.times.map { |i| (start_month + i.months).beginning_of_month.to_date }

    assignment_ids.each_with_object({}) do |aid, out|
      pairs = check_in_months_by_assignment[aid] || []
      out[aid] = months.map do |month|
        effective_pair = pairs.select { |m, _, _| m <= month }.last
        status = effective_pair ? effective_pair[1].to_sym : :none
        actual = effective_pair && effective_pair[0] == month
        source_check_in_date = effective_pair ? effective_pair[2] : nil
        {
          month: month,
          status: status,
          actual: actual,
          source_check_in_date: source_check_in_date
        }
      end
    end
  end

  # Summary for aspirational values: totals and eligibility status.
  # Returns { total_pass:, total_maybe:, total_miss:, pass_pct:, pass_maybe_pct:, threshold:, status: :eligible|:potentially_eligible|:working_to_meet }
  def build_aspirational_values_summary
    company_check = @eligibility_report[:checks].find { |c| c[:key] == :company_aspirational_values_check_in_requirements }
    threshold = [
      company_check&.dig(:details, :minimum_percentage_meeting),
      company_check&.dig(:details, :minimum_percentage_exceeding)
    ].compact.map(&:to_f).max
    threshold = nil if threshold.blank? || threshold <= 0

    total_pass = 0
    total_maybe = 0
    total_miss = 0
    total_disqualifiers = 0

    @aspirational_values_table_rows.each do |row_data|
      aspiration = row_data[:aspiration]
      details = company_check&.dig(:details) || {}
      monthly = @aspirational_values_monthly_status[aspiration.id] || []
      result = helpers.aspirational_value_row_result_for_details(monthly, details)
      case result
      when :pass then total_pass += 1
      when :maybe then total_maybe += 1
      when :miss then total_miss += 1
      end
      total_disqualifiers += 1 if helpers.row_has_disqualifier?(monthly, details)
    end

    total = total_pass + total_maybe + total_miss
    pass_pct = total.positive? ? (total_pass.to_f / total * 100).round(1) : 0
    pass_maybe_pct = total.positive? ? ((total_pass + total_maybe).to_f / total * 100).round(1) : 0

    status = if threshold.blank? || threshold <= 0
                nil
              elsif total_disqualifiers.positive?
                :working_to_meet
              elsif pass_pct >= threshold
                :eligible
              elsif pass_maybe_pct >= threshold
                :potentially_eligible
              else
                :working_to_meet
              end

    {
      total_pass: total_pass,
      total_maybe: total_maybe,
      total_miss: total_miss,
      total_disqualifiers: total_disqualifiers,
      pass_pct: pass_pct,
      pass_maybe_pct: pass_maybe_pct,
      threshold: threshold,
      status: status
    }
  end

  # 3-level eligibility: row categories and summary via CheckInRequirementsEligibility::Calculator.
  def build_check_in_eligibility_result(check, row_ids, monthly_status_by_id)
    details = check&.dig(:details) || {}
    minimum_months = (details[:minimum_months_at_or_above_rating_criteria] || details["minimum_months_at_or_above_rating_criteria"]).to_i
    minimum_months = 12 if minimum_months <= 0
    meeting_pct = details[:minimum_percentage_meeting] || details["minimum_percentage_meeting"] || details["minimum_percentage_of_aspirational_values_meeting"] || details["minimum_percentage_of_assignments_meeting"]
    exceeding_pct = details[:minimum_percentage_exceeding] || details["minimum_percentage_exceeding"] || details["minimum_percentage_of_aspirational_values_exceeding"] || details["minimum_percentage_of_assignments_exceeding"]
    CheckInRequirementsEligibility::Calculator.new(
      row_ids: row_ids,
      monthly_statuses_by_row_id: monthly_status_by_id,
      minimum_months: minimum_months,
      meeting_threshold_pct: meeting_pct,
      exceeding_threshold_pct: exceeding_pct
    ).call
  end

  # Generic summary for a check-in requirements section (aspirational or assignments).
  # check: report check hash; item_ids: aspiration or assignment ids; monthly_status_by_id: id => [monthly cells].
  def build_check_in_requirements_summary(check, item_ids, monthly_status_by_id)
    details = check&.dig(:details) || {}
    threshold = [
      details[:minimum_percentage_meeting],
      details[:minimum_percentage_exceeding],
      details['minimum_percentage_meeting'],
      details['minimum_percentage_exceeding']
    ].compact.map(&:to_f).max
    threshold = nil if threshold.blank? || threshold <= 0

    total_pass = 0
    total_maybe = 0
    total_miss = 0
    total_disqualifiers = 0

    Array(item_ids).each do |id|
      monthly = monthly_status_by_id[id] || []
      result = helpers.aspirational_value_row_result_for_details(monthly, details)
      case result
      when :pass then total_pass += 1
      when :maybe then total_maybe += 1
      when :miss then total_miss += 1
      end
      total_disqualifiers += 1 if helpers.row_has_disqualifier?(monthly, details)
    end

    total = total_pass + total_maybe + total_miss
    pass_pct = total.positive? ? (total_pass.to_f / total * 100).round(1) : 0
    pass_maybe_pct = total.positive? ? ((total_pass + total_maybe).to_f / total * 100).round(1) : 0

    status = if threshold.blank? || threshold <= 0
               nil
             elsif total_disqualifiers.positive?
               :working_to_meet
             elsif pass_pct >= threshold
               :eligible
             elsif pass_maybe_pct >= threshold
               :potentially_eligible
             else
               :working_to_meet
             end

    {
      total_pass: total_pass,
      total_maybe: total_maybe,
      total_miss: total_miss,
      total_disqualifiers: total_disqualifiers,
      pass_pct: pass_pct,
      pass_maybe_pct: pass_maybe_pct,
      threshold: threshold,
      status: status
    }
  end

  # Summary for required assignments: totals and eligibility status (same shape as aspirational values summary).
  def build_required_assignments_summary
    required_check = @eligibility_report[:checks].find { |c| c[:key] == :required_assignment_check_in_requirements }
    details = required_check&.dig(:details) || {}
    threshold = [
      details[:minimum_percentage_meeting],
      details[:minimum_percentage_exceeding]
    ].compact.map(&:to_f).max
    threshold = nil if threshold.blank? || threshold <= 0

    total_pass = 0
    total_maybe = 0
    total_miss = 0
    total_disqualifiers = 0

    @required_assignments.each do |assignment|
      monthly = @required_assignments_monthly_status[assignment.id] || []
      result = helpers.aspirational_value_row_result_for_details(monthly, details)
      case result
      when :pass then total_pass += 1
      when :maybe then total_maybe += 1
      when :miss then total_miss += 1
      end
      total_disqualifiers += 1 if helpers.row_has_disqualifier?(monthly, details)
    end

    total = total_pass + total_maybe + total_miss
    pass_pct = total.positive? ? (total_pass.to_f / total * 100).round(1) : 0
    pass_maybe_pct = total.positive? ? ((total_pass + total_maybe).to_f / total * 100).round(1) : 0

    status = if threshold.blank? || threshold <= 0
                nil
              elsif total_disqualifiers.positive?
                :working_to_meet
              elsif pass_pct >= threshold
                :eligible
              elsif pass_maybe_pct >= threshold
                :potentially_eligible
              else
                :working_to_meet
              end

    {
      total_pass: total_pass,
      total_maybe: total_maybe,
      total_miss: total_miss,
      total_disqualifiers: total_disqualifiers,
      pass_pct: pass_pct,
      pass_maybe_pct: pass_maybe_pct,
      threshold: threshold,
      status: status
    }
  end

  def selectable_teammates
    return [] unless current_person

    teammates = []
    teammates << current_company_teammate if current_company_teammate

    if CompanyTeammate.can_manage_employment_in_hierarchy?(current_person, organization)
      teammates.concat(
        CompanyTeammate.for_organization_hierarchy(organization)
                .where(last_terminated_at: nil)
                .includes(:person)
      )
    else
      reports = EmployeeHierarchyQuery.new(person: current_person, organization: organization).call
      report_person_ids = reports.map { |report| report[:person_id] }
      org_ids = organization.company? ? organization.self_and_descendants.map(&:id) : [organization.id]

      teammates.concat(
        CompanyTeammate.where(organization_id: org_ids, person_id: report_person_ids, last_terminated_at: nil)
                .includes(:person)
      )
    end

    teammates.compact.uniq { |teammate| teammate.id }.sort_by { |teammate| teammate.person.display_name }
  end

  def teammate_allowed?(teammate)
    return false unless teammate
    return true if current_company_teammate && teammate.id == current_company_teammate.id

    selectable_teammates.any? { |allowed| allowed.id == teammate.id }
  end

  def unique_to_you_assignments(teammate, position)
    return [] unless teammate && position

    required_assignment_ids = position.required_assignments.pluck(:assignment_id)
    teammate.assignment_tenures.active
            .where.not(assignment_id: required_assignment_ids)
            .includes(:assignment)
            .map(&:assignment)
            .uniq
  end

  # For section (1) footer: array of { company_teammate: } (teammate first, then managers in order) for casual_name + link.
  def build_managerial_hierarchy_for_display
    chain = [{ company_teammate: @teammate }]
    managers = ManagerialHierarchyQuery.new(person: @teammate.person, organization: organization).call
    managers.each do |m|
      ct = CompanyTeammate.find_by(person_id: m[:person_id], organization_id: organization.id)
      chain << { company_teammate: ct } if ct
    end
    chain
  end

  # Section (8): One row of 12-month status for position check-ins (any position). Returns { position: [ { month:, status:, actual:, source_check_in_date: }, ... ] }.
  # Maps official_rating (1-3) to :meeting/:exceeding and lower to :working_to_meet.
  def build_position_check_in_monthly_status(pos_check)
    start_month = 12.months.ago.beginning_of_month.to_date
    end_month = 1.month.ago.end_of_month.to_date

    check_ins = PositionCheckIn.closed
      .where(company_teammate: @teammate)
      .where(check_in_started_on: start_month..end_month)
      .order(:check_in_started_on)
      .pluck(:check_in_started_on, :official_rating)

    # Best rating per month (later check-in in same month overwrites)
    by_month = check_ins.each_with_object(Hash.new { |h, k| h[k] = nil }) do |(started_on, rating), h|
      month = started_on.beginning_of_month.to_date
      next if rating.blank?
      current = h[month]
      # Keep higher rating (3 > 2 > 1)
      h[month] = { rating: rating.to_i, check_in_date: started_on } if current.nil? || rating.to_i > current[:rating]
    end

    months = 12.times.map { |i| (start_month + i.months).beginning_of_month.to_date }
    # Carry forward: for each month, use most recent check-in on or before that month
    pairs = months.map do |month|
      key = by_month.keys.select { |m| m <= month }.max
      key ? by_month[key] : nil
    end

    status_array = months.each_with_index.map do |month, i|
      pair = pairs[i]
      status = if pair.nil?
        :none
      elsif pair[:rating] >= 3
        :exceeding
      elsif pair[:rating] >= 2
        :meeting
      else
        :working_to_meet
      end
      actual = by_month[month].present?
      {
        month: month,
        status: status,
        actual: actual,
        source_check_in_date: pair&.dig(:check_in_date)
      }
    end

    { position: status_array }
  end

  # Section (8): Eligibility result for the single position check-in row (100% must meet).
  def build_position_check_in_eligibility_result(pos_check)
    return nil unless @position_check_in_monthly_status_by_row_id.present?

    details = pos_check[:details] || {}
    minimum_months = (details[:minimum_months_at_or_above_rating_criteria] || details["minimum_months_at_or_above_rating_criteria"]).to_i
    minimum_months = 12 if minimum_months <= 0

    CheckInRequirementsEligibility::Calculator.new(
      row_ids: [:position],
      monthly_statuses_by_row_id: @position_check_in_monthly_status_by_row_id,
      minimum_months: minimum_months,
      meeting_threshold_pct: 100,
      exceeding_threshold_pct: 0
    ).call
  end
end
