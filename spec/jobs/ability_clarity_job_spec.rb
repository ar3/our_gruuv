# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilityClarityJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:creator) { create(:person) }
  let!(:ability) { create(:ability, company: organization, created_by: creator, updated_by: creator) }
  let!(:run) do
    MaapAgentRun.create!(
      subject: ability,
      agent_kind: MaapAgentRun::AGENT_KIND_ABILITY_CLARITY,
      status: 'pending',
      prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION
    )
  end

  it 'invokes the runner' do
    expect(Maap::AbilityClarityRunner).to receive(:call).with(
      ability: ability,
      maap_agent_run: run
    ).and_return(true)

    described_class.perform_now(ability.id, run.id)
  end
end
