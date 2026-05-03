# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PositionClarityJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let!(:position) { create(:position, title: title, position_level: position_level) }
  let!(:run) do
    MaapAgentRun.create!(
      subject: position,
      agent_kind: MaapAgentRun::AGENT_KIND_POSITION_CLARITY,
      status: 'pending',
      prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION
    )
  end

  it 'invokes the runner' do
    expect(Maap::PositionClarityRunner).to receive(:call).with(
      position: position,
      maap_agent_run: run
    ).and_return(true)

    described_class.perform_now(position.id, run.id)
  end
end
