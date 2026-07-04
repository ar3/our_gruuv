# frozen_string_literal: true

require 'csv'

class CheckInsHealthEmployeeSummaryCsvBuilder
  SECTIONS = [
    ['Aspirations', 'Aspiration'],
    ['Assignments', 'Assignment'],
    ['Position', 'Position']
  ].freeze

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
      'Total Percentage Healthy',
      *SECTIONS.flat_map do |label, _|
        [
          "#{label} Percentage Healthy",
          "#{label} Percentage At Risk",
          "#{label} Percentage Needs Attention"
        ]
      end
    ]
  end

  def rows
    records_by_teammate_id = EngagementHealth::ClarityMetrics.records_by_teammate_id(
      organization: organization,
      teammate_ids: teammate_ids
    )

    active_teammates.map do |teammate|
      person = teammate.person
      manager = teammate.current_manager
      tenure = teammate.active_employment_tenure
      position = tenure&.position
      title = position&.title
      department = title&.department
      records = records_by_teammate_id[teammate.id] || []
      build_row(
        person: person,
        manager: manager,
        position: position,
        title: title,
        department: department,
        records: records
      )
    end
  end

  def build_row(person:, manager:, position:, title:, department:, records:)
    breakdown = EngagementHealth::ClarityMetrics.breakdown(records)
    row = [
      person&.display_name.to_s,
      person&.email.to_s,
      position&.display_name.to_s,
      title&.display_name.to_s,
      department&.display_name.to_s,
      manager&.display_name.to_s,
      manager&.email.to_s,
      format_pct(breakdown&.fetch(:completion_rate, 0) || 0)
    ]

    SECTIONS.each do |_label, entity_type|
      percents = EngagementHealth::ClarityMetrics.csv_section_status_percents(
        records,
        entity_type: entity_type
      )
      row << format_pct(percents[EngagementHealth::HEALTHY])
      row << format_pct(percents[EngagementHealth::AT_RISK])
      row << format_pct(percents[EngagementHealth::NEEDS_ATTENTION])
    end

    row
  end

  def format_pct(value)
    "#{value.to_f.round(1)}%"
  end
end
