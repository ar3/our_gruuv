# frozen_string_literal: true

module JobDescriptionAcknowledgements
  # Whether the teammate's latest signature clears the current due trigger.
  # Due triggers: last position change (or first tenure start), and last
  # manager-finalized position check-in. One signature after the latest trigger clears both.
  class ComplianceStatus
    WARNING_WINDOW = 30.days

    Result = Struct.new(
      :compliant?,
      :latest_trigger_at,
      :latest_signature_at,
      :due_by,
      keyword_init: true
    )

    def self.call(teammate:, organization:, acknowledgements: nil)
      new(
        teammate: teammate,
        organization: organization,
        acknowledgements: acknowledgements
      ).call
    end

    def initialize(teammate:, organization:, acknowledgements: nil)
      @teammate = teammate
      @organization = organization
      @acknowledgements = acknowledgements
    end

    def call
      trigger_at = latest_trigger_at
      signature_at = latest_signature_at
      compliant = trigger_at.present? && signature_at.present? && signature_at >= trigger_at

      Result.new(
        compliant?: compliant,
        latest_trigger_at: trigger_at,
        latest_signature_at: signature_at,
        due_by: trigger_at&.+(WARNING_WINDOW)
      )
    end

    private

    def latest_signature_at
      records = @acknowledgements
      records = @teammate.job_description_acknowledgements if records.nil?
      Array(records).map(&:signed_at).compact.max
    end

    def latest_trigger_at
      [last_position_change_at, last_finalized_position_check_in_at].compact.max
    end

    def last_position_change_at
      tenures = @teammate.employment_tenures.where(company: @organization).to_a
      return if tenures.empty?

      metrics = EmploymentTenures::HistoryMetrics.call(tenures: tenures)
      metrics[:last_promotion_at] || metrics[:sorted_tenures].first&.started_at
    end

    def last_finalized_position_check_in_at
      PositionCheckIn
        .where(company_teammate: @teammate)
        .closed
        .where(employment_tenure_id: @teammate.employment_tenures.where(company: @organization).select(:id))
        .maximum(:official_check_in_completed_at)
    end
  end
end
