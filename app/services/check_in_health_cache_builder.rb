# frozen_string_literal: true

class CheckInHealthCacheBuilder
  DAYS_THRESHOLD = 90

  def self.call(teammate, organization)
    new(teammate, organization).call
  end

  def initialize(teammate, organization)
    @teammate = teammate
    @organization = organization
    @cutoff = DAYS_THRESHOLD.days.ago
  end

  def call
    {
      'position' => build_position,
      'assignments' => build_assignments,
      'aspirations' => build_aspirations,
      'milestones' => build_milestones
    }
  end

  def build_and_save
    payload = call
    cache = CheckInHealthCache.find_or_initialize_by(teammate: teammate, organization: organization)
    cache.payload = payload
    cache.refreshed_at = Time.current
    cache.save!
    cache
  end

  private

  attr_reader :teammate, :organization, :cutoff

  def build_position
    open_ci = PositionCheckIn.where(company_teammate: teammate).open.first
    closed_ci = PositionCheckIn.where(company_teammate: teammate).closed
      .order(official_check_in_completed_at: :desc).first
    item_from_check_ins(open_ci, closed_ci, nil)
  end

  def build_assignments
    active_assignments = teammate.assignment_tenures
      .active
      .joins(:assignment)
      .where(assignments: { company: organization.self_and_descendants })
      .includes(:assignment)
      .distinct

    active_assignments.map do |tenure|
      open_ci = AssignmentCheckIn.where(company_teammate: teammate, assignment: tenure.assignment).open.first
      closed_ci = AssignmentCheckIn.where(company_teammate: teammate, assignment: tenure.assignment).closed
        .order(official_check_in_completed_at: :desc).first
      item_from_check_ins(open_ci, closed_ci, tenure.assignment_id)
    end
  end

  def build_aspirations
    aspirations = Aspiration.within_hierarchy(organization)
    aspirations.map do |aspiration|
      open_ci = AspirationCheckIn.where(company_teammate: teammate, aspiration: aspiration).open.first
      closed_ci = AspirationCheckIn.where(company_teammate: teammate, aspiration: aspiration).closed
        .order(official_check_in_completed_at: :desc).first
      item_from_check_ins(open_ci, closed_ci, aspiration.id)
    end
  end

  def item_from_check_ins(open_ci, closed_ci, item_id)
    result = {
      'item_id' => item_id,
      'employee_completed_at' => nil,
      'manager_completed_at' => nil,
      'official_check_in_completed_at' => nil,
      'acknowledged_at' => nil,
      'category' => 'red'
    }

    # Prefer latest activity: closed in window, then open in window
    finalized_in_window = closed_ci && closed_ci.official_check_in_completed_at && closed_ci.official_check_in_completed_at >= cutoff
    if finalized_in_window
      result['official_check_in_completed_at'] = closed_ci.official_check_in_completed_at&.iso8601
      result['employee_completed_at'] = closed_ci.employee_completed_at&.iso8601
      result['manager_completed_at'] = closed_ci.manager_completed_at&.iso8601
      ack_at = closed_ci.maap_snapshot&.employee_acknowledged_at
      result['acknowledged_at'] = ack_at&.iso8601 if ack_at
      result['category'] = (ack_at && ack_at >= cutoff) ? 'neon_green' : 'green'
      return result
    end

    # Open check-in with both sides completed in last 90 days
    if open_ci
      emp_at = open_ci.employee_completed_at
      mgr_at = open_ci.manager_completed_at
      result['employee_completed_at'] = emp_at&.iso8601
      result['manager_completed_at'] = mgr_at&.iso8601
      emp_in_window = emp_at && emp_at >= cutoff
      mgr_in_window = mgr_at && mgr_at >= cutoff
      if emp_in_window && mgr_in_window
        result['category'] = 'light_green'
        return result
      end
      if emp_in_window && !mgr_in_window
        result['category'] = 'light_blue'
        return result
      end
      if mgr_in_window && !emp_in_window
        result['category'] = 'light_purple'
        return result
      end
    end

    # Orange: had finalized before or at least one open started (any completion ever)
    had_finalized_before = closed_ci.present?
    open_started = open_ci && (open_ci.employee_completed_at.present? || open_ci.manager_completed_at.present?)
    if had_finalized_before || open_started
      result['official_check_in_completed_at'] = closed_ci.official_check_in_completed_at&.iso8601 if closed_ci
      result['employee_completed_at'] = open_ci&.employee_completed_at&.iso8601
      result['manager_completed_at'] = (open_ci&.manager_completed_at || closed_ci&.manager_completed_at)&.iso8601
      ack_at = closed_ci&.maap_snapshot&.employee_acknowledged_at
      result['acknowledged_at'] = ack_at&.iso8601 if ack_at
      result['category'] = 'orange'
      return result
    end

    result
  end

  def build_milestones
    active_assignments = teammate.assignment_tenures
      .active
      .joins(:assignment)
      .where(assignments: { company: organization.self_and_descendants })
      .includes(assignment: :assignment_abilities)

    required_milestones = Set.new
    active_assignments.each do |tenure|
      tenure.assignment.assignment_abilities.each do |aa|
        required_milestones.add([aa.ability_id, aa.milestone_level])
      end
    end

    active_tenure = teammate.active_employment_tenure
    if active_tenure&.position
      active_tenure.position.position_abilities.each do |pa|
        required_milestones.add([pa.ability_id, pa.milestone_level])
      end
    end

    attained = teammate.teammate_milestones
      .joins(:ability)
      .where(abilities: { company_id: organization.self_and_descendants.pluck(:id) })

    earned_count = required_milestones.count do |(ability_id, milestone_level)|
      attained.any? { |tm| tm.ability_id == ability_id && tm.milestone_level >= milestone_level }
    end

    {
      'total_required' => required_milestones.size,
      'earned_count' => earned_count
    }
  end
end
