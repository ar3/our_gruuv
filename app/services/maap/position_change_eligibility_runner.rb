# frozen_string_literal: true

module Maap
  class PositionChangeEligibilityRunner
    def self.call(teammate:, position:, organization:, og_consultation:)
      new(
        teammate: teammate,
        position: position,
        organization: organization,
        og_consultation: og_consultation
      ).call
    end

    def initialize(teammate:, position:, organization:, og_consultation:)
      @teammate = teammate
      @position = position
      @organization = organization
      @consultation = og_consultation
    end

    def call
      unless bedrock_configured?
        fail_consultation('AWS Bedrock is not configured (missing access key, secret, or region).')
        return false
      end

      builder = PositionChangeEligibilityPayloadBuilder.new(
        teammate: @teammate,
        position: @position,
        organization: @organization
      )
      built = builder.call

      @consultation.update!(units_total: built.units_total, units_completed: 0)

      result = @consultation.position_change_eligibility_result ||
               @consultation.create_position_change_eligibility_result!(
                 position: @position,
                 change_type: built.change_type
               )
      result.update!(position: @position, change_type: built.change_type)

      shared_text = run_llm(
        purpose: 'position_change_eligibility',
        system_instructions: Maap::Prompts::POSITION_CHANGE_ELIGIBILITY_AGENT,
        user_prompt: PayloadRenderer.new(built.payload).to_markdown
      )
      result.update!(output_text: shared_text)
      @consultation.increment_units_completed!

      manager_ran = false
      teammate_ran = false

      if built.manager_private_present
        manager_text = run_llm(
          purpose: 'position_change_eligibility_manager_overlay',
          system_instructions: Maap::Prompts::POSITION_CHANGE_ELIGIBILITY_MANAGER_OVERLAY_AGENT,
          user_prompt: PayloadRenderer.new(builder.manager_overlay_payload(shared_output_text: shared_text)).to_markdown
        )
        result.update!(manager_only_output_text: manager_text, manager_only_ran: true)
        manager_ran = true
        @consultation.increment_units_completed!
      end

      if built.teammate_private_present
        teammate_text = run_llm(
          purpose: 'position_change_eligibility_teammate_overlay',
          system_instructions: Maap::Prompts::POSITION_CHANGE_ELIGIBILITY_TEAMMATE_OVERLAY_AGENT,
          user_prompt: PayloadRenderer.new(builder.teammate_overlay_payload(shared_output_text: shared_text)).to_markdown
        )
        result.update!(teammate_only_output_text: teammate_text, teammate_only_ran: true)
        teammate_ran = true
        @consultation.increment_units_completed!
      end

      result.update!(manager_only_ran: manager_ran, teammate_only_ran: teammate_ran)
      @consultation.update!(
        status: 'completed',
        result: result,
        model_id: model_id,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
        completed_at: Time.current,
        error_message: nil
      )
      true
    rescue StandardError => e
      Rails.logger.warn("PositionChangeEligibilityRunner failed: #{e.class}: #{e.message}")
      fail_consultation(e.message)
      false
    end

    private

    def run_llm(purpose:, system_instructions:, user_prompt:)
      footer = <<~MD

        ---
        Prompt version: #{Maap::Prompts::MAAP_PROMPTS_VERSION}
      MD

      llm = Llm::Client.call(
        purpose: purpose,
        model_id: model_id,
        system_instructions: system_instructions,
        user_prompt: "#{user_prompt}#{footer}",
        organization_id: @organization.id,
        triggered_by_teammate_id: @consultation.triggered_by_teammate_id,
        parent: @consultation,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION
      )
      llm.content.to_s.strip
    end

    def model_id
      # Position-Change Eligibility is a high-stakes year-horizon read — default to Sonnet 4.5.
      # Override with POSITION_CHANGE_ELIGIBILITY_BEDROCK_MODEL_ID if needed.
      @model_id ||= ENV.fetch('POSITION_CHANGE_ELIGIBILITY_BEDROCK_MODEL_ID') {
        Llm::SlackMomentsExtractor.stronger_model_id
      }
    end

    def fail_consultation(message)
      @consultation.update!(
        status: 'failed',
        error_message: message.to_s.truncate(10_000),
        model_id: model_id,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
        completed_at: Time.current
      )
    end

    def bedrock_configured?
      cfg = RubyLLM.config
      cfg.bedrock_api_key.present? && cfg.bedrock_secret_key.present? && cfg.bedrock_region.present?
    end
  end
end
