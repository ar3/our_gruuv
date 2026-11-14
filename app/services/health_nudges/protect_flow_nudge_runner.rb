# frozen_string_literal: true

module HealthNudges
  class ProtectFlowNudgeRunner
    def self.call(og_consultation:)
      new(og_consultation: og_consultation).call
    end

    def initialize(og_consultation:)
      @consultation = og_consultation
      @result = og_consultation.result
      @result = ProtectFlowNudgeResult.find_by(og_consultation_id: og_consultation.id) if @result.blank?
    end

    def call
      unless bedrock_configured?
        fail_consultation("AWS Bedrock is not configured (missing access key, secret, or region).")
        return false
      end

      payload = (@result&.payload || {}).stringify_keys
      manager = @consultation.subject
      organization = @consultation.organization
      suggested = payload["suggested_body"].to_s
      people_ids = Array(payload["people_teammate_ids"]).map(&:to_i)
      teammates = CompanyTeammate.where(id: people_ids).includes(:person)
      store = ProtectFlow::WeekSnapshotStore.for(
        person: @consultation.triggered_by_teammate.person,
        organization: organization
      )
      plan = ProtectFlow::PlanBuilder.call(
        organization: organization,
        week_store: store,
        teammates: teammates.to_a,
        viewer: @consultation.triggered_by_teammate
      )
      context = ProtectFlowNudgeContextBuilder.call(
        organization: organization,
        people: plan[:people],
        viewer: @consultation.triggered_by_teammate
      )
      context_json = JSON.pretty_generate(context).truncate(24_000)

      model_id = ENV.fetch("PROTECT_FLOW_NUDGE_BEDROCK_MODEL_ID") { Llm::TranscriptMomentsExtractor.default_model_id }
      purpose = OgConsultations::Kinds.fetch(@consultation.kind).llm_purpose
      llm = Llm::Client.call(
        purpose: purpose,
        model_id: model_id,
        system_instructions: ProtectFlowNudgePrompts::SYSTEM_INSTRUCTIONS,
        user_prompt: ProtectFlowNudgePrompts.user_prompt(
          manager_name: manager.person&.casual_name || "Manager",
          context_json: context_json,
          suggested_body: suggested
        ),
        organization_id: @consultation.organization_id,
        triggered_by_teammate_id: @consultation.triggered_by_teammate_id,
        parent: @consultation,
        prompt_version: ProtectFlowNudgePrompts::PROMPT_VERSION
      )

      draft_body = llm.content.to_s.strip
      draft_body = suggested if draft_body.blank?
      draft_body = draft_body.truncate(SuggestedBody::MAX_CHARS)

      @result.update!(
        output_text: draft_body,
        payload: payload.merge("draft_body" => draft_body)
      )
      @consultation.update!(
        status: "completed",
        completed_at: Time.current,
        units_completed: 1,
        result: @result
      )

      DraftStore.for(
        person: @consultation.triggered_by_teammate.person,
        organization: organization,
        manager_teammate: manager
      ).record_consultation!(consultation_id: @consultation.id, og_consulted_body: draft_body)

      true
    rescue StandardError => e
      fail_consultation(e.message)
      false
    end

    private

    def bedrock_configured?
      ENV["AWS_ACCESS_KEY_ID"].present? && ENV["AWS_SECRET_ACCESS_KEY"].present? && ENV["AWS_REGION"].present?
    end

    def fail_consultation(message)
      @consultation.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: message.to_s.truncate(500)
      )
    end
  end
end
