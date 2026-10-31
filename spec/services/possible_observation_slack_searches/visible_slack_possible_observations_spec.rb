# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::VisibleSlackPossibleObservations do
  let(:organization) { create(:organization, :company) }
  let(:viewer) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:other_searcher) { create(:company_teammate, :assigned_employee, organization: organization) }

  it "shows public moments to any viewer and private only to discoverers" do
    public_row = create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discoverer_company_teammate_ids: [other_searcher.id]
    )
    private_for_other = create(
      :slack_possible_observation,
      :private_or_dm,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discoverer_company_teammate_ids: [other_searcher.id]
    )
    private_for_viewer = create(
      :slack_possible_observation,
      :private_or_dm,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discoverer_company_teammate_ids: [viewer.id]
    )

    result = described_class.call(
      subject: subject_teammate,
      viewer: viewer,
      organization: organization
    )

    expect(result).to include(public_row, private_for_viewer)
    expect(result).not_to include(private_for_other)
  end

  it "hides dismissed rows and rows with an existing Slack OGO" do
    dismissed = create(
      :slack_possible_observation,
      :dismissed,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discoverer_company_teammate_ids: [viewer.id]
    )
    with_ogo = create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discoverer_company_teammate_ids: [viewer.id],
      channel_id: "Cogo",
      message_ts: "1710000000.009900"
    )
    open_row = create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discoverer_company_teammate_ids: [viewer.id]
    )

    trigger = create(
      :observation_trigger,
      trigger_source: "slack",
      trigger_data: { "channel_id" => "Cogo", "message_ts" => "1710000000.009900" }
    )
    create(:observation, company: organization, observer: viewer.person, observation_trigger: trigger)

    result = described_class.call(
      subject: subject_teammate,
      viewer: viewer,
      organization: organization
    )

    expect(result).to eq([open_row])
    expect(result).not_to include(dismissed, with_ogo)
  end
end
