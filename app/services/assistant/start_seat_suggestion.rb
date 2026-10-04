# frozen_string_literal: true

module Assistant
  # Starts a Seat Suggestion thread (non-billable) and enqueues the job.
  class StartSeatSuggestion
    def self.call(...) = new(...).call

    def initialize(organization:, company_teammate:, query:)
      @organization = organization
      @company_teammate = company_teammate
      @query = query.to_s.strip
    end

    def call
      return Result.err("query is required") if @query.blank?

      entry = OgConsultations::Kinds.fetch(OgConsultation::KIND_SEAT_SUGGESTION)

      consultation = nil
      ActiveRecord::Base.transaction do
        consultation = OgConsultation.create!(
          kind: entry.kind,
          subject: @organization,
          organization_id: @organization.id,
          triggered_by_teammate: @company_teammate,
          status: "pending",
          billable: entry.billable,
          prompt_version: Assistant::SeatSuggestionPrompts::SEAT_SUGGESTION_PROMPT_VERSION,
          units_total: 1,
          units_completed: 0
        )
        result = AskOgResult.create!(
          og_consultation: consultation,
          query: @query
        )
        consultation.update!(result: result)
        result.append_message!(role: AskOgMessage::ROLE_USER, body: @query)
      end

      entry.job_class.perform_later(consultation.id)
      Result.ok(consultation: consultation, result: consultation.result)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages)
    end
  end
end
