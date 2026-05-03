# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeammateGrowthJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let!(:teammate) { create(:company_teammate, :assigned_employee, organization: organization) }
  let!(:run) do
    MaapAgentRun.create!(
      subject: teammate,
      agent_kind: MaapAgentRun::AGENT_KIND_TEAMMATE_GROWTH,
      status: 'pending',
      prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION
    )
  end

  it 'invokes the runner' do
    expect(Maap::TeammateGrowthRunner).to receive(:call).with(
      teammate: teammate,
      organization: organization,
      maap_agent_run: run
    ).and_return(true)

    described_class.perform_now(teammate.id, organization.id, run.id)
  end
end
