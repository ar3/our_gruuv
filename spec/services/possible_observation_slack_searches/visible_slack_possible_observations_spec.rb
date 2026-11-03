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

    expect(result.map(&:moment)).to include(public_row, private_for_viewer)
    expect(result.map(&:moment)).not_to include(private_for_other)
  end

  it "hides dismissed and published OGOs, but keeps draft-linked moments" do
    dismissed = create(
      :slack_possible_observation,
      :dismissed,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discoverer_company_teammate_ids: [viewer.id]
    )
    with_published = create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discoverer_company_teammate_ids: [viewer.id],
      channel_id: "Cpub",
      message_ts: "1710000000.009900"
    )
    with_draft = create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discoverer_company_teammate_ids: [viewer.id],
      channel_id: "Cdraft",
      message_ts: "1710000000.008800"
    )
    open_row = create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discoverer_company_teammate_ids: [viewer.id]
    )

    published_trigger = create(
      :observation_trigger,
      trigger_source: "slack",
      trigger_data: { "channel_id" => "Cpub", "message_ts" => "1710000000.009900" }
    )
    create(
      :observation,
      company: organization,
      observer: viewer.person,
      observation_trigger: published_trigger,
      published_at: Time.current
    )

    draft_trigger = create(
      :observation_trigger,
      trigger_source: "slack",
      trigger_data: { "channel_id" => "Cdraft", "message_ts" => "1710000000.008800" }
    )
    draft = create(
      :observation,
      company: organization,
      observer: viewer.person,
      observation_trigger: draft_trigger,
      published_at: nil
    )

    result = described_class.call(
      subject: subject_teammate,
      viewer: viewer,
      organization: organization
    )

    moments = result.map(&:moment)
    expect(moments).to include(open_row, with_draft)
    expect(moments).not_to include(dismissed, with_published)
    draft_row = result.find { |row| row.moment == with_draft }
    expect(draft_row.draft_observation).to eq(draft)
  end
end
