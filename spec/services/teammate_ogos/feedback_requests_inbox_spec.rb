# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeammateOgos::FeedbackRequestsInbox do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:other) { create(:company_teammate, organization: organization) }
  let(:requestor) { create(:company_teammate, organization: organization) }

  def call(show_closed: false)
    described_class.call(
      organization: organization,
      teammate: teammate,
      current_person: person,
      viewing_company_teammate: teammate,
      show_closed: show_closed
    )
  end

  def section(key)
    call[:sections].find { |s| s.key == key }
  end

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: other, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: requestor, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "buckets requests into three non-overlapping sections" do
    waiting = create(:feedback_request, company: organization, requestor_teammate: requestor, subject_of_feedback_teammate: other)
    waiting.feedback_request_responders.create!(teammate: teammate)

    about_by_other = create(:feedback_request, company: organization, requestor_teammate: requestor, subject_of_feedback_teammate: teammate)
    about_self_ask = create(:feedback_request, company: organization, requestor_teammate: teammate, subject_of_feedback_teammate: teammate)
    for_others = create(:feedback_request, company: organization, requestor_teammate: teammate, subject_of_feedback_teammate: other)

    expect(section(:waiting).rows.map(&:feedback_request)).to eq([waiting])
    expect(section(:about).rows.map(&:feedback_request)).to contain_exactly(about_by_other, about_self_ask)
    expect(section(:asked_for_others).rows.map(&:feedback_request)).to eq([for_others])
    expect(call[:sections].map(&:key)).to eq([:waiting, :about, :asked_for_others])
  end

  it "includes open-link incomplete answers in Waiting on after a responder row exists" do
    open_request = create(:feedback_request, :ready_open_link,
      company: organization,
      requestor_teammate: requestor,
      subject_of_feedback_teammate: other
    )
    open_request.feedback_request_responders.create!(teammate: teammate, completed_at: nil)

    expect(section(:waiting).rows.map(&:feedback_request)).to include(open_request)
  end

  it "excludes completed responder rows from Waiting on unless show_closed" do
    request = create(:feedback_request, company: organization, requestor_teammate: requestor, subject_of_feedback_teammate: other)
    request.feedback_request_responders.create!(teammate: teammate, completed_at: Time.current)

    expect(section(:waiting).rows).to be_empty
    expect(call(show_closed: true)[:sections].find { |s| s.key == :waiting }.rows.map(&:feedback_request)).to include(request)
  end

  it "hides archived requests unless show_closed" do
    create(:feedback_request, :archived, company: organization, requestor_teammate: requestor, subject_of_feedback_teammate: teammate)

    expect(section(:about).rows).to be_empty
    expect(call(show_closed: true)[:sections].find { |s| s.key == :about }.rows).not_to be_empty
  end
end
