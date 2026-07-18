# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Llm::Client do
  let(:organization) { create(:organization, :company) }
  let(:response_double) do
    instance_double(
      RubyLLM::Message,
      content: 'hello from model',
      input_tokens: 10,
      output_tokens: 5,
      cached_tokens: 0,
      cache_creation_tokens: 0
    )
  end
  let(:chat_double) { instance_double(RubyLLM::Chat) }

  before do
    allow(RubyLLM).to receive(:chat).and_return(chat_double)
    allow(chat_double).to receive(:with_instructions).and_return(chat_double)
    allow(chat_double).to receive(:ask).and_return(response_double)
  end

  it 'persists an LlmInvocation with tokens, cost, duration, and payloads' do
    result = nil
    expect do
      result = described_class.call(
        purpose: 'ability_clarity',
        model_id: 'us.anthropic.claude-haiku-4-5-20251001-v1:0',
        system_instructions: 'sys',
        user_prompt: 'user',
        organization_id: organization.id
      )
    end.to change(LlmInvocation, :count).by(1)

    invocation = result.invocation
    expect(result.content).to eq('hello from model')
    expect(invocation.status).to eq('completed')
    expect(invocation.input_tokens).to eq(10)
    expect(invocation.output_tokens).to eq(5)
    expect(invocation.cost_micros).to be > 0
    expect(invocation.duration_ms).to be >= 0
    expect(invocation.request_payload).to be_attached
    expect(invocation.response_payload).to be_attached
    expect(invocation.request_payload.blob.key).to include("llm_invocations/org_#{organization.id}/")
    expect(invocation.request_payload.blob.key).to end_with('/request.json')
  end

  it 'marks the invocation failed and re-raises on error' do
    allow(chat_double).to receive(:ask).and_raise(StandardError, 'boom')

    expect do
      described_class.call(
        purpose: 'ability_clarity',
        model_id: 'us.anthropic.claude-haiku-4-5-20251001-v1:0',
        system_instructions: 'sys',
        user_prompt: 'user',
        organization_id: organization.id,
        store_payloads: false
      )
    end.to raise_error(StandardError, 'boom')

    invocation = LlmInvocation.order(:id).last
    expect(invocation.status).to eq('failed')
    expect(invocation.error_message).to eq('boom')
  end
end
