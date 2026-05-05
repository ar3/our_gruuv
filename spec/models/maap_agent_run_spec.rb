require 'rails_helper'

RSpec.describe MaapAgentRun, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:ability) { create(:ability, company: organization) }

  describe 'paper trail completion markers' do
    it 'marks completion versions with completed_event metadata' do
      run = described_class.create!(
        subject: ability,
        agent_kind: described_class::AGENT_KIND_ABILITY_CLARITY,
        status: 'pending',
        triggered_by_teammate: teammate,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION
      )

      run.update!(status: 'completed')

      version = run.versions.last

      expect(version.meta['completed_event']).to eq(true)
      expect(version.meta['completed_triggered_by_teammate_id']).to eq(teammate.id)
    end

    it 'does not mark non-completion versions as completed_event' do
      run = described_class.create!(
        subject: ability,
        agent_kind: described_class::AGENT_KIND_ABILITY_CLARITY,
        status: 'pending',
        triggered_by_teammate: teammate,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION
      )

      run.update!(status: 'processing')

      version = run.versions.last

      expect(version.meta['completed_event']).not_to eq(true)
    end
  end
end
