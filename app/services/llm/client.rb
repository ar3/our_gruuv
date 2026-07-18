# frozen_string_literal: true

require 'json'
require 'stringio'

module Llm
  # Single entrypoint for Bedrock calls via RubyLLM. Always records an LlmInvocation
  # (tokens, cost, duration) and optionally ActiveStorage request/response payloads.
  class Client
    Result = Data.define(:content, :response, :invocation)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(
      purpose:,
      model_id:,
      system_instructions:,
      user_prompt:,
      organization_id: nil,
      triggered_by_teammate_id: nil,
      parent: nil,
      prompt_version: nil,
      store_payloads: true
    )
      @purpose = purpose
      @model_id = model_id
      @system_instructions = system_instructions
      @user_prompt = user_prompt
      @organization_id = organization_id
      @triggered_by_teammate_id = triggered_by_teammate_id
      @parent = parent
      @prompt_version = prompt_version
      @store_payloads = store_payloads
    end

    def call
      invocation = LlmInvocation.create!(
        purpose: @purpose,
        model_id: @model_id,
        status: 'processing',
        organization_id: @organization_id,
        triggered_by_teammate_id: @triggered_by_teammate_id,
        parent: @parent,
        prompt_version: @prompt_version,
        started_at: Time.current
      )

      chat = RubyLLM.chat(model: @model_id, provider: :bedrock, assume_model_exists: true)
      chat.with_instructions(@system_instructions.to_s) if @system_instructions.present?
      response = chat.ask(@user_prompt.to_s)
      finished_at = Time.current

      input_tokens = response.input_tokens.to_i
      output_tokens = response.output_tokens.to_i
      cached_tokens = response.cached_tokens.to_i
      cache_creation_tokens = response.cache_creation_tokens.to_i
      cost_micros = BedrockCostCalculator.cost_micros(
        model_id: @model_id,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        cached_tokens: cached_tokens,
        cache_creation_tokens: cache_creation_tokens
      )

      invocation.update!(
        status: 'completed',
        finished_at: finished_at,
        duration_ms: duration_ms(invocation.started_at, finished_at),
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        cached_tokens: cached_tokens,
        cache_creation_tokens: cache_creation_tokens,
        cost_micros: cost_micros,
        error_message: nil
      )

      attach_payloads(invocation, response.content.to_s) if @store_payloads

      Result.new(content: response.content.to_s, response: response, invocation: invocation)
    rescue StandardError => e
      finished_at = Time.current
      if invocation&.persisted?
        invocation.update!(
          status: 'failed',
          finished_at: finished_at,
          duration_ms: duration_ms(invocation.started_at, finished_at),
          error_message: e.message.to_s.truncate(10_000)
        )
        attach_payloads(invocation, nil) if @store_payloads
      end
      raise
    end

    private

    def duration_ms(started_at, finished_at)
      return nil if started_at.blank? || finished_at.blank?

      ((finished_at - started_at) * 1000).round
    end

    def attach_payloads(invocation, response_text)
      request_body = {
        system_instructions: @system_instructions.to_s,
        user_prompt: @user_prompt.to_s,
        model_id: @model_id,
        purpose: @purpose,
        prompt_version: @prompt_version
      }.to_json

      attach_blob(
        invocation,
        :request_payload,
        body: request_body,
        filename: 'request.json'
      )

      return if response_text.nil?

      response_body = { content: response_text }.to_json
      attach_blob(
        invocation,
        :response_payload,
        body: response_body,
        filename: 'response.json'
      )
    rescue StandardError => e
      Rails.logger.warn("Llm::Client payload attach failed: #{e.class}: #{e.message}")
    end

    def attach_blob(invocation, attachment_name, body:, filename:)
      key = payload_key(invocation, filename)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(body),
        filename: filename,
        content_type: 'application/json',
        key: key
      )
      invocation.public_send(attachment_name).attach(blob)
    end

    def payload_key(invocation, filename)
      org_segment = @organization_id.present? ? "org_#{@organization_id}" : 'org_unknown'
      t = (invocation.started_at || Time.current).utc
      month = t.strftime('%Y-%m')
      day_folder = "#{t.strftime('%Y_%m_%d')}_invocation_#{invocation.id}"
      "llm_invocations/#{org_segment}/#{month}/#{day_folder}/#{filename}"
    end
  end
end
