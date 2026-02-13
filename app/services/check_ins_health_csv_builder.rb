# frozen_string_literal: true

require 'csv'

class CheckInsHealthCsvBuilder
  ASSIGNMENT_RATING_NUMBERS = {
    'working_to_meet' => -1,
    'meeting' => 0,
    'exceeding' => 1
  }.freeze

  ASSIGNMENT_RATING_LABELS = {
    'working_to_meet' => 'Working to Meet',
    'meeting' => 'Meeting',
    'exceeding' => 'Exceeding'
  }.freeze

  def initialize(organization, active_teammates)
    @organization = organization
    @active_teammates = active_teammates.respond_to?(:to_ary) ? active_teammates.to_ary : active_teammates.to_a
    @teammate_ids = @active_teammates.map(&:id)
    @org_ids = organization.self_and_descendants.pluck(:id)
  end

  def call
    CSV.generate(headers: true) do |csv|
      csv << headers
      rows.each { |row| csv << row }
    end
  end

  private

  attr_reader :organization, :active_teammates, :teammate_ids, :org_ids

  def headers
    [
      'Teammate Name',
      'Teammate Email',
      'Teammate Manager Name',
      'Teammate Manager Email',
      'Check-in Object',
      'Check-in Started',
      'Check-in Finalized',
      'Check-ins Finalized Before this',
      'Manager Check-in Completed At',
      'Manager who completed Check-in',
      'Employee Check-in Completed At',
      'Rating',
      'Shared Notes',
      'Employee Rating',
      'Employee Notes',
      'Manager Rating',
      'Manager Notes',
      'Expected Energy Percentage',
      'Actual Energy Percentage',
      'Employee Personal Alignment'
    ]
  end

  def rows
    out = []
    position_check_ins_with_meta.each { |meta| out << position_row(meta) }
    assignment_check_ins_with_meta.each { |meta| out << assignment_row(meta) }
    aspiration_check_ins_with_meta.each { |meta| out << aspiration_row(meta) }
    out
  end

  def finalized_before_index(object_key, check_in)
    return nil unless check_in.closed?

    group = finalized_order_by_object[object_key]
    return nil unless group

    idx = group.find_index { |c| c.id == check_in.id }
    idx
  end

  def finalized_order_by_object
    @finalized_order_by_object ||= begin
      by_key = Hash.new { |h, k| h[k] = [] }
      [position_check_ins_with_meta, assignment_check_ins_with_meta, aspiration_check_ins_with_meta].each do |list|
        list.each do |meta|
          ci = meta[:check_in]
          next unless ci.closed?

          by_key[meta[:object_key]] << ci
        end
      end
      by_key.each_value do |arr|
        arr.sort_by! { |c| c.official_check_in_completed_at || Time.at(0) }
        arr.reverse!
      end
      by_key
    end
  end

  def position_row(meta)
    ci = meta[:check_in]
    person = meta[:person]
    manager = meta[:manager]
    finalized_before = finalized_before_index(meta[:object_key], ci)

    [
      person&.display_name.to_s,
      person&.email.to_s,
      manager&.display_name.to_s,
      manager&.email.to_s,
      meta[:object_name],
      format_date(ci.check_in_started_on),
      format_datetime(ci.official_check_in_completed_at),
      finalized_before.nil? ? '' : finalized_before.to_s,
      format_datetime(ci.manager_completed_at),
      ci.manager_completed_by_teammate&.person&.display_name.to_s,
      format_datetime(ci.employee_completed_at),
      position_rating_format(ci.official_rating),
      ci.shared_notes.to_s,
      position_rating_format(ci.employee_rating),
      ci.employee_private_notes.to_s,
      position_rating_format(ci.manager_rating),
      ci.manager_private_notes.to_s,
      '', # Expected Energy Percentage
      '', # Actual Energy Percentage
      ''  # Employee Personal Alignment
    ]
  end

  def assignment_row(meta)
    ci = meta[:check_in]
    person = meta[:person]
    manager = meta[:manager]
    finalized_before = finalized_before_index(meta[:object_key], ci)
    tenure = ci.assignment_tenure

    [
      person&.display_name.to_s,
      person&.email.to_s,
      manager&.display_name.to_s,
      manager&.email.to_s,
      meta[:object_name],
      format_date(ci.check_in_started_on),
      format_datetime(ci.official_check_in_completed_at),
      finalized_before.nil? ? '' : finalized_before.to_s,
      format_datetime(ci.manager_completed_at),
      ci.manager_completed_by_teammate&.person&.display_name.to_s,
      format_datetime(ci.employee_completed_at),
      assignment_rating_format(ci.official_rating),
      ci.shared_notes.to_s,
      assignment_rating_format(ci.employee_rating),
      ci.employee_private_notes.to_s,
      assignment_rating_format(ci.manager_rating),
      ci.manager_private_notes.to_s,
      tenure&.anticipated_energy_percentage.to_s,
      ci.actual_energy_percentage.to_s,
      ci.employee_personal_alignment.to_s
    ]
  end

  def aspiration_row(meta)
    ci = meta[:check_in]
    person = meta[:person]
    manager = meta[:manager]
    finalized_before = finalized_before_index(meta[:object_key], ci)

    [
      person&.display_name.to_s,
      person&.email.to_s,
      manager&.display_name.to_s,
      manager&.email.to_s,
      meta[:object_name],
      format_date(ci.check_in_started_on),
      format_datetime(ci.official_check_in_completed_at),
      finalized_before.nil? ? '' : finalized_before.to_s,
      format_datetime(ci.manager_completed_at),
      ci.manager_completed_by_teammate&.person&.display_name.to_s,
      format_datetime(ci.employee_completed_at),
      assignment_rating_format(ci.official_rating),
      ci.shared_notes.to_s,
      assignment_rating_format(ci.employee_rating),
      ci.employee_private_notes.to_s,
      assignment_rating_format(ci.manager_rating),
      ci.manager_private_notes.to_s,
      '',
      '',
      ''
    ]
  end

  def format_date(value)
    value.respond_to?(:strftime) ? value.strftime('%Y-%m-%d') : value.to_s
  end

  def format_datetime(value)
    return '' if value.blank?
    value.respond_to?(:strftime) ? value.strftime('%Y-%m-%d %H:%M') : value.to_s
  end

  def position_rating_format(rating)
    return '' if rating.nil?
    data = EmploymentTenure::POSITION_RATINGS[rating]
    return rating.to_s if data.nil?
    "#{rating} - #{data[:label]}"
  end

  def assignment_rating_format(rating)
    return '' if rating.blank?
    num = ASSIGNMENT_RATING_NUMBERS[rating.to_s]
    label = ASSIGNMENT_RATING_LABELS[rating.to_s] || rating.to_s.humanize
    "#{num} - #{label}"
  end

  # Lazy-load finalized order after we've built meta lists once (avoid N+1 and double load).
  # We need to compute finalized_before from the same lists we iterate for rows.
  # So we'll compute finalized_order_by_object from the same data. But position_check_ins_with_meta
  # etc. are called multiple times - we should memoize them.
  def position_check_ins_with_meta
    @position_check_ins_with_meta ||= load_position_check_ins_with_meta
  end

  def assignment_check_ins_with_meta
    @assignment_check_ins_with_meta ||= load_assignment_check_ins_with_meta
  end

  def aspiration_check_ins_with_meta
    @aspiration_check_ins_with_meta ||= load_aspiration_check_ins_with_meta
  end

  def load_position_check_ins_with_meta
    return [] if teammate_ids.blank?

    PositionCheckIn
      .where(teammate_id: teammate_ids)
      .includes(
        company_teammate: :person,
        employment_tenure: { position: [], manager_teammate: :person },
        manager_completed_by_teammate: :person,
        finalized_by_teammate: :person
      )
      .order(:check_in_started_on)
      .map do |ci|
        teammate = ci.company_teammate
        {
          check_in: ci,
          teammate: teammate,
          person: teammate.person,
          manager: teammate.current_manager,
          object_name: ci.employment_tenure&.position&.display_name.to_s,
          object_key: "position_#{teammate.id}"
        }
      end
  end

  def load_assignment_check_ins_with_meta
    return [] if teammate_ids.blank?

    AssignmentCheckIn
      .where(teammate_id: teammate_ids)
      .joins(:assignment)
      .where(assignments: { company_id: org_ids })
      .includes(
        :assignment,
        company_teammate: :person,
        manager_completed_by_teammate: :person,
        finalized_by_teammate: :person
      )
      .order(:check_in_started_on)
      .map do |ci|
        teammate = ci.company_teammate
        {
          check_in: ci,
          teammate: teammate,
          person: teammate.person,
          manager: teammate.current_manager,
          object_name: ci.assignment&.display_name.to_s,
          object_key: "assignment_#{teammate.id}_#{ci.assignment_id}"
        }
      end
  end

  def load_aspiration_check_ins_with_meta
    return [] if teammate_ids.blank?

    aspiration_ids = Aspiration.within_hierarchy(organization).pluck(:id)
    return [] if aspiration_ids.blank?

    AspirationCheckIn
      .where(teammate_id: teammate_ids, aspiration_id: aspiration_ids)
      .includes(
        :aspiration,
        company_teammate: :person,
        manager_completed_by_teammate: :person,
        finalized_by_teammate: :person
      )
      .order(:check_in_started_on)
      .map do |ci|
        teammate = ci.company_teammate
        {
          check_in: ci,
          teammate: teammate,
          person: teammate.person,
          manager: teammate.current_manager,
          object_name: ci.aspiration&.name.to_s,
          object_key: "aspiration_#{teammate.id}_#{ci.aspiration_id}"
        }
      end
  end
end
