# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::SlackOgoConsult::DurableCandidateFilter do
  let(:organization) { create(:organization, :company) }
  let(:viewer) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:other_assignment) { create(:assignment, company: organization) }

  def create_moment(rateable:, confidence:, ts:, **attrs)
    create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discoverer_company_teammate_ids: [viewer.id],
      message_ts: ts,
      payload: {
        "summary" => "moment",
        "quote" => "quote",
        "confidence" => confidence,
        "suggested_rateable_type" => rateable.class.name,
        "suggested_rateable_id" => rateable.id
      }.merge(attrs.fetch(:payload, {}))
    )
  end

  it "keeps high-confidence object matches in range and counts others" do
    match = create_moment(rateable: assignment, confidence: 0.9, ts: 5.days.ago.to_f.to_s)
    other = create_moment(rateable: other_assignment, confidence: 0.85, ts: 5.days.ago.to_f.to_s)
    create_moment(rateable: assignment, confidence: 0.7, ts: 5.days.ago.to_f.to_s)
    create_moment(rateable: assignment, confidence: 0.95, ts: 60.days.ago.to_f.to_s)

    result = described_class.call(
      subject: subject_teammate,
      viewer: viewer,
      organization: organization,
      rateable_type: "Assignment",
      rateable_id: assignment.id,
      since: 30.days.ago,
      until_time: Time.current
    )

    expect(result[:object_matches].map(&:record)).to eq([match])
    expect(result[:other_matches].map(&:record)).to eq([other])
  end
end
