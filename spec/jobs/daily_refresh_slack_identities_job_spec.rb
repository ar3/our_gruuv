require 'rails_helper'

RSpec.describe DailyRefreshSlackIdentitiesJob, type: :job do
  describe '#perform' do
    it 'enqueues auto-sync jobs with the system actor ids' do
      org_with_slack = create(:organization, :with_slack_config)
      create(:organization)
      system_person = create(:person, email: 'automation@og.local')
      allow(SystemActor).to receive(:person).and_return(system_person)

      expect {
        described_class.perform_now
      }.to have_enqueued_job(RefreshSlackIdentitiesAutoSyncJob).with(
        org_with_slack.id,
        system_person.id,
        system_person.id,
        'daily'
      ).once
    end
  end
end
