# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailyRefreshObservationHealthCachesJob, type: :job do
  let(:organization) { create(:organization, :company) }

  describe "#perform" do
    it "enqueues refresh jobs for employed teammates" do
      employed = create(:teammate, organization: organization, first_employed_at: 1.month.ago)
      create(:teammate, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: 1.day.ago)

      expect {
        described_class.perform_now
      }.to have_enqueued_job(ObservationHealthCacheRefreshJob).with(employed.id)

      expect(ObservationHealthCacheRefreshJob).to have_been_enqueued.exactly(:once)
    end
  end
end
