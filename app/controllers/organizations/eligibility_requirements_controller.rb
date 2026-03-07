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
    # Get aspirations for the title's department (if any)
    @title_department_aspirations = @position.title.department ? 
      Aspiration.for_department(@position.title.department).ordered : 
      Aspiration.none

    # Aspirational values table: one row per value with 12-month teammate status
    @aspirational_values_monthly_status = aspirational_values_monthly_status(@teammate, @company_aspirations.to_a + @title_department_aspirations.to_a)
    @aspirational_values_table_rows = build_aspirational_values_table_rows
    @aspirational_values_summary = build_aspirational_values_summary

    # Required assignments table: one row per assignment with 12-month teammate status
    @required_assignments_monthly_status = assignment_monthly_status(@teammate, @required_assignments)
    @required_assignments_summary = build_required_assignments_summary

    # Collapsible summary: sentences per check and abilities with max milestone required
    @eligibility_requirements_sentences = build_eligibility_requirements_sentences
    @ability_milestone_requirements = build_ability_milestone_requirements
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

  # Rows for aspirational values table: [ { aspiration:, section: 'company'|'title_department' }, ... ]
  def build_aspirational_values_table_rows
    rows = []
    @company_aspirations.each { |a| rows << { aspiration: a, section: 'company' } }
    @title_department_aspirations.each { |a| rows << { aspiration: a, section: 'title_department' } }
    rows
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
    title_check = @eligibility_report[:checks].find { |c| c[:key] == :title_department_aspirational_values_check_in_requirements }
    threshold = [
      company_check&.dig(:details, :minimum_percentage_meeting),
      company_check&.dig(:details, :minimum_percentage_exceeding),
      title_check&.dig(:details, :minimum_percentage_meeting),
      title_check&.dig(:details, :minimum_percentage_exceeding)
    ].compact.map(&:to_f).max
    threshold = nil if threshold.blank? || threshold <= 0

    total_pass = 0
    total_maybe = 0
    total_miss = 0
    total_disqualifiers = 0

    @aspirational_values_table_rows.each do |row_data|
      aspiration = row_data[:aspiration]
      section = row_data[:section]
      section_check = (section == 'company') ? company_check : title_check
      details = section_check&.dig(:details) || {}
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
end
