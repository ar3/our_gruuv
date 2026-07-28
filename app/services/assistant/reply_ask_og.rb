# frozen_string_literal: true

module Assistant
  # Appends a user reply to an Ask OG thread and enqueues the next assistant turn.
  class ReplyAskOg
    def self.call(...) = new(...).call

    def initialize(og_consultation:, message:)
      @consultation = og_consultation
      @message = message.to_s.strip
    end

    def call
      return Result.err("message is required") if @message.blank?
      return Result.err("Ask OG result missing") unless @consultation.result.is_a?(AskOgResult)
      return Result.err("Ask OG is still thinking") if @consultation.in_flight?

      result = @consultation.result
      ActiveRecord::Base.transaction do
        result.append_message!(role: AskOgMessage::ROLE_USER, body: @message)
        @consultation.update!(
          status: "pending",
          units_total: @consultation.units_total.to_i + 1,
          error_message: nil,
          completed_at: nil
        )
      end

      OgConsultations::Kinds.fetch(@consultation.kind).job_class.perform_later(@consultation.id)
      Result.ok(consultation: @consultation, result: result)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages)
    end
  end
end
