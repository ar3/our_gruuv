# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observations::UnpublishService do
  let(:organization) { create(:organization, :company) }
  let(:observer_teammate) { create(:teammate, organization: organization, first_employed_at: 1.month.ago) }
  let(:observee_teammate) { create(:teammate, organization: organization, first_employed_at: 1.month.ago) }

  def published_observation
    build(:observation, observer: observer_teammate.person, company: organization, published_at: 1.day.ago, story: "Hi").tap do |obs|
      obs.observees.build(teammate: observee_teammate)
      obs.save!
    end
  end

  describe ".call" do
    it "clears published_at and enqueues cache refresh jobs" do
      observation = published_observation
      expect {
        described_class.call(observation)
      }.to change { observation.reload.published_at }.to(nil)
        .and have_enqueued_job(ObservationHealthCacheRefreshJob).with(observer_teammate.id)
        .and have_enqueued_job(ObservationHealthCacheRefreshJob).with(observee_teammate.id)
    end

    it "returns false when observation is already a draft" do
      observation = build(:observation, observer: observer_teammate.person, company: organization, published_at: nil, story: "Draft")
      observation.save!
      expect(described_class.call(observation)).to be false
      expect(ObservationHealthCacheRefreshJob).not_to have_been_enqueued
    end
  end
end
