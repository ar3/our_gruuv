# frozen_string_literal: true

module CheckIns
  class StartPeriodBriefConsult
    Result = Data.define(:ok, :consultation, :check_in, :error) do
      def ok?
        ok
      end
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, triggered_by_teammate:, check_in:)
      @organization = organization
      @triggered_by_teammate = triggered_by_teammate
      @check_in = check_in
    end

    def call
      return fail_result("Open check-in required.") if @check_in.blank?
      return fail_result("Check-in is already finalized.") if @check_in.officially_completed?

      inflight = @check_in.latest_period_brief_consultation
      if inflight&.in_flight?
        return Result.new(ok: true, consultation: inflight, check_in: @check_in, error: nil)
      end

      entry = OgConsultations::Kinds.fetch(OgConsultation::KIND_CHECK_IN_PERIOD_BRIEF)
      consultation = OgConsultation.create!(
        kind: entry.kind,
        subject: @check_in,
        organization_id: @organization.id,
        triggered_by_teammate: @triggered_by_teammate,
        status: "pending",
        billable: entry.billable,
        prompt_version: PeriodBriefPrompts::PROMPT_VERSION,
        units_total: 1,
        units_completed: 0
      )
      result = CheckInPeriodBriefResult.create!(og_consultation: consultation, payload: {})
      consultation.update!(result: result)
      CheckInPeriodBriefJob.perform_later(@check_in.class.name, @check_in.id, consultation.id)

      Result.new(ok: true, consultation: consultation, check_in: @check_in, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      fail_result(e.record.errors.full_messages.to_sentence.presence || e.message)
    end

    private

    def fail_result(message)
      Result.new(ok: false, consultation: nil, check_in: @check_in, error: message)
    end
  end
end
