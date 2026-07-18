# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin LLM Invocations', type: :request do
  let(:organization) { create(:organization) }

  def create_invocation!(purpose:, input_tokens: 1_000, output_tokens: 200)
    LlmInvocation.create!(
      purpose: purpose,
      model_id: 'us.anthropic.claude-haiku-4-5-20251001-v1:0',
      status: 'completed',
      organization: organization,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cached_tokens: 0,
      cache_creation_tokens: 0,
      duration_ms: 1_200,
      cost_micros: Llm::BedrockCostCalculator.cost_micros(
        model_id: 'us.anthropic.claude-haiku-4-5-20251001-v1:0',
        input_tokens: input_tokens,
        output_tokens: output_tokens
      ),
      finished_at: Time.current
    )
  end

  describe 'GET /admin/llm_invocations' do
    context 'as og_admin' do
      let(:person) { create(:person, :admin) }

      before do
        sign_in_as_teammate_for_request(person, organization)
        6.times { |i| create_invocation!(purpose: 'ability_clarity', input_tokens: 1_000 + i) }
        create_invocation!(purpose: 'slack_chunk')
      end

      it 'renders recent invocations grouped by purpose with anticipated cost' do
        get admin_llm_invocations_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Admin: LLM Invocations')
        expect(response.body).to include('Ability Clarity')
        expect(response.body).to include('Slack Chunk')
        expect(response.body).to include('Anticipated')
        expect(response.body).to include('in 1,005')
        # Oldest of 6 ability_clarity rows (1,000 in) should be omitted
        expect(response.body).not_to include('in 1,000 /')
      end
    end

    context 'as non-admin' do
      let(:person) { create(:person) }

      before { sign_in_as_teammate_for_request(person, organization) }

      it 'is forbidden' do
        get admin_llm_invocations_path
        expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /organizations link' do
    let(:person) { create(:person, :admin) }

    before { sign_in_as_teammate_for_request(person, organization) }

    it 'links to the LLM invocations admin page from organizations index' do
      get organizations_path

      expect(response.body).to include('Admin: LLM Invocations')
      expect(response.body).to include(admin_llm_invocations_path)
    end
  end
end
