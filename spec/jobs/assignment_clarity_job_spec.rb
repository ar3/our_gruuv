# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AssignmentClarityJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let!(:assignment) { create(:assignment, company: organization) }
  let!(:run) do
    MaapAgentRun.create!(
      subject: assignment,
      agent_kind: MaapAgentRun::AGENT_KIND_ASSIGNMENT_CLARITY,
      status: 'pending',
      prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION
    )
  end

  it 'invokes the runner' do
    expect(Maap::AssignmentClarityRunner).to receive(:call).with(
      assignment: assignment,
      maap_agent_run: run
    ).and_return(true)

    described_class.perform_now(assignment.id, run.id)
  end
end
