# frozen_string_literal: true

module HealthNudges
  class StartProtectFlowNudgeConsult
    Result = Data.define(:ok, :consultation, :error) do
      def ok?
        ok
      end
    end

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(organization:, manager_teammate:, nudger_teammate:, people:, spotlight_stats:)
      @organization = organization
      @manager_teammate = manager_teammate
      @nudger_teammate = nudger_teammate
      @people = Array(people)
      @spotlight_stats = spotlight_stats
    end

    def call
      draft = DraftStore.for(
        person: @nudger_teammate.person,
        organization: @organization,
        manager_teammate: @manager_teammate
      )
      message = Message.new(
        health_object: "protect_flow",
        organization: @organization,
        manager_teammate: @manager_teammate,
        spotlight_stats: @spotlight_stats,
        employee_count: @people.size
      )
      suggested = SuggestedBody.call(message: message, people: @people)
      draft.ensure_suggested!(suggested)

      inflight = OgConsultation
        .where(
          kind: OgConsultation::KIND_PROTECT_FLOW_NUDGE,
          subject: @manager_teammate,
          organization: @organization,
          triggered_by_teammate: @nudger_teammate
        )
        .where("created_at >= ?", Time.zone.now.beginning_of_day)
        .latest_first
        .detect(&:in_flight?)
      if inflight
        draft.record_inflight_consultation!(consultation_id: inflight.id)
        return Result.new(ok: true, consultation: inflight, error: nil)
      end

      entry = OgConsultations::Kinds.fetch(OgConsultation::KIND_PROTECT_FLOW_NUDGE)
      consultation = OgConsultation.create!(
        kind: entry.kind,
        subject: @manager_teammate,
        organization: @organization,
        triggered_by_teammate: @nudger_teammate,
        status: "pending",
        billable: entry.billable,
        prompt_version: ProtectFlowNudgePrompts::PROMPT_VERSION,
        units_total: 1,
        units_completed: 0
      )
      result = ProtectFlowNudgeResult.create!(
        og_consultation: consultation,
        payload: {
          "manager_teammate_id" => @manager_teammate.id,
          "people_teammate_ids" => @people.map { |p| p[:teammate_id] },
          "suggested_body" => suggested,
          "spotlight_stats" => @spotlight_stats.stringify_keys
        }
      )
      consultation.update!(result: result)
      draft.record_inflight_consultation!(consultation_id: consultation.id)
      ProtectFlowNudgeConsultJob.perform_later(consultation.id)

      Result.new(ok: true, consultation: consultation, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(ok: false, consultation: nil, error: e.record.errors.full_messages.to_sentence.presence || e.message)
    end
  end
end
