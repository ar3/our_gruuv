# frozen_string_literal: true

require 'csv'

class CheckInsHealthEmployeeSummaryCsvBuilder
  def initialize(organization, active_teammates)
    @organization = organization
    @active_teammates = active_teammates.respond_to?(:to_ary) ? active_teammates.to_ary : active_teammates.to_a
    @teammate_ids = @active_teammates.map(&:id)
  end

  def call
    CSV.generate(headers: true) do |csv|
      csv << headers
      rows.each { |row| csv << row }
    end
  end

  private

  attr_reader :organization, :active_teammates, :teammate_ids

  def headers
    [
      'Name',
      'Email',
      'Position',
      'Title',
      'Department',
      'Manager Name',
      'Manager Email',
      'Total Percentage Clear',
      'Aspirational Values Total Percentage Clear',
      'Aspirational Values Employee Checked-in Within 90 Days Percentage',
      'Aspirational Values Employee Checked-in Within 60 Days Percentage',
      'Aspirational Values Manager Checked-in Within 90 Days Percentage',
      'Aspirational Values Manager Checked-in Within 60 Days Percentage',
      'Aspirational Values Reviewed Checked-in Within 90 Days Percentage',
      'Aspirational Values Reviewed Checked-in Within 60 Days Percentage',
      'Aspirational Values Acknowledged Checked-in Within 90 Days Percentage',
      'Aspirational Values Acknowledged Checked-in Within 60 Days Percentage',
      'Required Assignments Total Percentage Clear',
      'Required Assignments Employee Checked-in Within 90 Days Percentage',
      'Required Assignments Employee Checked-in Within 60 Days Percentage',
      'Required Assignments Manager Checked-in Within 90 Days Percentage',
      'Required Assignments Manager Checked-in Within 60 Days Percentage',
      'Required Assignments Reviewed Checked-in Within 90 Days Percentage',
      'Required Assignments Reviewed Checked-in Within 60 Days Percentage',
      'Required Assignments Acknowledged Checked-in Within 90 Days Percentage',
      'Required Assignments Acknowledged Checked-in Within 60 Days Percentage',
      'Position Total Percentage Clear',
      'Position Employee Checked-in Within 90 Days Percentage',
      'Position Employee Checked-in Within 60 Days Percentage',
      'Position Manager Checked-in Within 90 Days Percentage',
      'Position Manager Checked-in Within 60 Days Percentage',
      'Position Reviewed Checked-in Within 90 Days Percentage',
      'Position Reviewed Checked-in Within 60 Days Percentage',
      'Position Acknowledged Checked-in Within 90 Days Percentage',
      'Position Acknowledged Checked-in Within 60 Days Percentage'
    ]
  end

  def rows
    caches_by_teammate_id = CheckInHealthCache.where(
      teammate_id: teammate_ids,
      organization_id: organization.id
    ).index_by(&:teammate_id)

    active_teammates.map do |teammate|
      person = teammate.person
      manager = teammate.current_manager
      tenure = teammate.active_employment_tenure
      position = tenure&.position
      title = position&.title
      department = title&.department
      cache = caches_by_teammate_id[teammate.id]
      build_row(
        person: person,
        manager: manager,
        position: position,
        title: title,
        department: department,
        cache: cache
      )
    end
  end

  def build_row(person:, manager:, position:, title:, department:, cache:)
    aspirations = cache&.payload_aspirations || []
    assignments = cache&.payload_assignments || []
    position_item = cache&.payload_position || {}

    [
      person&.display_name.to_s,
      person&.email.to_s,
      position&.display_name.to_s,
      title&.display_name.to_s,
      department&.display_name.to_s,
      manager&.display_name.to_s,
      manager&.email.to_s,
      format_pct(total_percentage_clear(cache)),
      format_pct(section_total_percentage_clear(cache, :aspirations)),
      format_pct(items_checked_in_within_pct(aspirations, :employee_completed_at, 90)),
      format_pct(items_checked_in_within_pct(aspirations, :employee_completed_at, 60)),
      format_pct(items_checked_in_within_pct(aspirations, :manager_completed_at, 90)),
      format_pct(items_checked_in_within_pct(aspirations, :manager_completed_at, 60)),
      format_pct(items_checked_in_within_pct(aspirations, :official_check_in_completed_at, 90)),
      format_pct(items_checked_in_within_pct(aspirations, :official_check_in_completed_at, 60)),
      format_pct(items_checked_in_within_pct(aspirations, :acknowledged_at, 90)),
      format_pct(items_checked_in_within_pct(aspirations, :acknowledged_at, 60)),
      format_pct(section_total_percentage_clear(cache, :assignments)),
      format_pct(items_checked_in_within_pct(assignments, :employee_completed_at, 90)),
      format_pct(items_checked_in_within_pct(assignments, :employee_completed_at, 60)),
      format_pct(items_checked_in_within_pct(assignments, :manager_completed_at, 90)),
      format_pct(items_checked_in_within_pct(assignments, :manager_completed_at, 60)),
      format_pct(items_checked_in_within_pct(assignments, :official_check_in_completed_at, 90)),
      format_pct(items_checked_in_within_pct(assignments, :official_check_in_completed_at, 60)),
      format_pct(items_checked_in_within_pct(assignments, :acknowledged_at, 90)),
      format_pct(items_checked_in_within_pct(assignments, :acknowledged_at, 60)),
      format_pct(section_total_percentage_clear(cache, :position)),
      format_pct(single_item_checked_in_within_pct(position_item, :employee_completed_at, 90)),
      format_pct(single_item_checked_in_within_pct(position_item, :employee_completed_at, 60)),
      format_pct(single_item_checked_in_within_pct(position_item, :manager_completed_at, 90)),
      format_pct(single_item_checked_in_within_pct(position_item, :manager_completed_at, 60)),
      format_pct(single_item_checked_in_within_pct(position_item, :official_check_in_completed_at, 90)),
      format_pct(single_item_checked_in_within_pct(position_item, :official_check_in_completed_at, 60)),
      format_pct(single_item_checked_in_within_pct(position_item, :acknowledged_at, 90)),
      format_pct(single_item_checked_in_within_pct(position_item, :acknowledged_at, 60))
    ]
  end

  def total_percentage_clear(cache)
    return 0 unless cache

    points = cache.completion_points
    pos_pts = points[:position].to_f
    assign_pts = points[:assignments].to_f
    aspir_pts = points[:aspirations].to_f

    pos_max = 4.0
    assign_max = (cache.payload_assignments.size * 4).to_f
    assign_max = 4.0 if cache.payload_assignments.empty?
    aspir_max = (cache.payload_aspirations.size * 4).to_f
    aspir_max = 4.0 if cache.payload_aspirations.empty?

    total_max = pos_max + assign_max + aspir_max
    return 0 if total_max.zero?

    (pos_pts + assign_pts + aspir_pts) / total_max * 100
  end

  def section_total_percentage_clear(cache, section)
    return 0 unless cache

    points = cache.completion_points
    case section
    when :aspirations
      max = (cache.payload_aspirations.size * 4).to_f
      max = 4.0 if cache.payload_aspirations.empty?
      return 0 if max.zero?
      points[:aspirations].to_f / max * 100
    when :assignments
      max = (cache.payload_assignments.size * 4).to_f
      max = 4.0 if cache.payload_assignments.empty?
      return 0 if max.zero?
      points[:assignments].to_f / max * 100
    when :position
      points[:position].to_f / 4.0 * 100
    else
      0
    end
  end

  def items_checked_in_within_pct(items, timestamp_key, days)
    items = Array(items)
    return 0 if items.empty?

    cutoff = Time.current - days.days
    matched = items.count { |item| within_cutoff?(item[timestamp_key.to_s], cutoff) }
    matched.to_f / items.size * 100
  end

  def single_item_checked_in_within_pct(item, timestamp_key, days)
    return 0 if item.blank?

    cutoff = Time.current - days.days
    within_cutoff?(item[timestamp_key.to_s], cutoff) ? 100 : 0
  end

  def within_cutoff?(value, cutoff)
    return false if value.blank?

    timestamp = Time.zone.parse(value.to_s) rescue nil
    timestamp.present? && timestamp >= cutoff
  end

  def format_pct(value)
    "#{value.to_f.round(1)}%"
  end
end
