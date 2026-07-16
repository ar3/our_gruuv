# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::DuplicateObservationsForMessage do
  let(:organization) { create(:organization) }
  let(:observer) { create(:person) }
  let(:teammate) { create(:company_teammate, person: observer, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
  end

  it "finds observations linked to the same Slack channel_id + message_ts" do
    trigger = create(
      :observation_trigger,
      trigger_source: "slack",
      trigger_type: "ogo_source_search",
      trigger_data: { "channel_id" => "C999", "message_ts" => "1710000000.000100", "permalink" => "https://example.slack.com/p" }
    )
    observation = create(:observation, company: organization, observer: observer, observation_trigger: trigger)

    results = described_class.call(organization: organization, channel_id: "C999", message_ts: "1710000000.000100")
    expect(results).to include(observation)
  end

  it "returns none when no matching trigger exists" do
    results = described_class.call(organization: organization, channel_id: "C999", message_ts: "1710000000.000100")
    expect(results).to be_empty
  end
end
