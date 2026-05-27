# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observations::HealthCacheRefresh do
  let(:organization) { create(:organization, :company) }
  let(:observer_teammate) { create(:teammate, organization: organization, first_employed_at: 1.month.ago) }
  let(:observee_teammate) { create(:teammate, organization: organization, first_employed_at: 1.month.ago) }
  let(:observation) do
    build(:observation, observer: observer_teammate.person, company: organization, published_at: 1.day.ago, story: "Hi").tap do |obs|
      obs.observees.clear
      obs.observees.build(teammate: observee_teammate)
      obs.save!
    end
  end

  describe ".teammate_ids_for" do
    it "includes observer and observee teammate ids" do
      expect(described_class.teammate_ids_for(observation)).to match_array(
        [observer_teammate.id, observee_teammate.id]
      )
    end
  end

  describe ".enqueue_for_observation" do
    it "enqueues a refresh job per involved teammate" do
      expect {
        described_class.enqueue_for_observation(observation)
      }.to have_enqueued_job(ObservationHealthCacheRefreshJob).with(observer_teammate.id)
        .and have_enqueued_job(ObservationHealthCacheRefreshJob).with(observee_teammate.id)
    end
  end
end
