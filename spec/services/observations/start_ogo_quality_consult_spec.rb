# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observations::StartOgoQualityConsult do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:triggered) { create(:teammate, person: person, organization: organization) }
  let(:observee) { create(:teammate, organization: organization) }
  let(:observation) { create(:observation, observer: person, company: organization, story: "A specific thing happened.") }

  it "returns an error when story is blank" do
    result = described_class.call(
      organization: organization,
      current_person: person,
      triggered_by_teammate: triggered,
      observation: observation,
      story: " ",
      observee_ids: observation.observees.map(&:teammate_id),
      observation_type: "kudos",
      privacy_level: "observed_and_managers"
    )

    expect(result).not_to be_ok
    expect(result.error).to include("story")
  end

  it "reuses an in-flight consultation instead of enqueueing another" do
    inflight = create_ogo_quality_consultation!(observation: observation, status: "processing")

    expect do
      result = described_class.call(
        organization: organization,
        current_person: person,
        triggered_by_teammate: triggered,
        observation: observation,
        story: observation.story,
        observee_ids: observation.observees.map(&:teammate_id),
        observation_type: "kudos",
        privacy_level: "observed_and_managers"
      )
      expect(result).to be_ok
      expect(result.consultation).to eq(inflight)
    end.not_to have_enqueued_job(OgoQualityJob)
  end
end
