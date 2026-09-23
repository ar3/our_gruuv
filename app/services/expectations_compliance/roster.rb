# frozen_string_literal: true

module ExpectationsCompliance
  # Builds Expectations Compliance roster rows for filtered active teammates.
  class Roster
    Row = Struct.new(
      :teammate,
      :compliant,
      :due_by,
      :latest_signature_at,
      :latest_trigger_at,
      :last_finalized_position_check_in_at,
      :employment_seconds,
      :last_position_change_at,
      :current_position_name,
      :previous_position_name,
      :manager_name,
      :direct_report_count,
      :hierarchical_report_count,
      keyword_init: true
    )

    def self.call(organization:, teammates:)
      new(organization: organization, teammates: teammates).call
    end

    def initialize(organization:, teammates:)
      @organization = organization
      @teammates = Array(teammates)
    end

    def call
      return [] if @teammates.empty?

      teammate_ids = @teammates.map(&:id)
      acknowledgements_by_teammate = load_acknowledgements(teammate_ids)
      finalized_check_ins_by_teammate = load_finalized_check_ins(teammate_ids)
      tenures_by_teammate = load_tenures(teammate_ids)
      direct_report_counts = load_direct_report_counts(teammate_ids)

      rows = @teammates.map do |teammate|
        tenures = tenures_by_teammate[teammate.id] || []
        metrics = EmploymentTenures::HistoryMetrics.call(tenures: tenures)
        current_tenure = current_tenure_for(metrics[:sorted_tenures])
        acknowledgements = acknowledgements_by_teammate[teammate.id] || []
        status = JobDescriptionAcknowledgements::ComplianceStatus.call(
          teammate: teammate,
          organization: @organization,
          acknowledgements: acknowledgements
        )

        Row.new(
          teammate: teammate,
          compliant: status.compliant?,
          due_by: status.due_by,
          latest_signature_at: status.latest_signature_at,
          latest_trigger_at: status.latest_trigger_at,
          last_finalized_position_check_in_at: finalized_check_ins_by_teammate[teammate.id],
          employment_seconds: metrics[:total_employed_seconds],
          last_position_change_at: metrics[:last_promotion_at] || metrics[:sorted_tenures].first&.started_at,
          current_position_name: current_tenure&.position&.display_name,
          previous_position_name: previous_position_name(metrics[:sorted_tenures], current_tenure),
          manager_name: current_tenure&.manager_teammate&.person&.casual_name,
          direct_report_count: direct_report_counts[teammate.id].to_i,
          hierarchical_report_count: hierarchical_report_count_excluding_self(teammate)
        )
      end

      rows.sort_by { |row| sort_key(row) }
    end

    private

    def load_acknowledgements(teammate_ids)
      JobDescriptionAcknowledgement
        .where(company_teammate_id: teammate_ids, organization_id: @organization.id)
        .order(signed_at: :desc)
        .group_by(&:company_teammate_id)
    end

    def load_finalized_check_ins(teammate_ids)
      tenure_ids = EmploymentTenure.where(company: @organization, teammate_id: teammate_ids).select(:id)
      PositionCheckIn
        .closed
        .where(teammate_id: teammate_ids, employment_tenure_id: tenure_ids)
        .group(:teammate_id)
        .maximum(:official_check_in_completed_at)
    end

    def load_tenures(teammate_ids)
      EmploymentTenure
        .where(company: @organization, teammate_id: teammate_ids)
        .includes(:position, manager_teammate: :person)
        .order(:started_at)
        .group_by(&:teammate_id)
    end

    def load_direct_report_counts(teammate_ids)
      EmploymentTenure
        .where(company: @organization, ended_at: nil, manager_teammate_id: teammate_ids)
        .group(:manager_teammate_id)
        .count("DISTINCT teammate_id")
    end

    def current_tenure_for(sorted_tenures)
      sorted_tenures.reverse.find { |tenure| tenure.ended_at.nil? } || sorted_tenures.last
    end

    def previous_position_name(sorted_tenures, current_tenure)
      return if current_tenure.blank?

      sorted_tenures.reverse_each.find do |tenure|
        tenure.started_at < current_tenure.started_at && tenure.position_id != current_tenure.position_id
      end&.position&.display_name
    end

    def hierarchical_report_count_excluding_self(teammate)
      ids = CompanyTeammate.self_and_reporting_hierarchy(teammate, @organization).map(&:id)
      [ids.size - 1, 0].max
    end

    def sort_key(row)
      status_rank =
        if row.compliant
          2
        elsif row.due_by.present? && row.due_by < Time.current
          0
        else
          1
        end

      [
        status_rank,
        row.due_by || Time.zone.at(0),
        row.teammate.person&.last_name.to_s.downcase,
        row.teammate.person&.first_name.to_s.downcase
      ]
    end
  end
end
