# frozen_string_literal: true

require "rails_helper"

RSpec.describe CoachInbox::Builder do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, :assigned_employee, person: person, organization: organization) }

  it "returns four sections with subtype counts collapsed by default" do
    sections = described_class.call(organization: organization, teammates: [teammate])

    expect(sections.map(&:key)).to eq(%i[check_ins ogos goals expectation_alignment])
    expect(sections.flat_map(&:subtypes).map(&:expanded)).to all(be(false))
    expect(sections.flat_map(&:subtypes).map(&:items)).to all(be_empty)
    expect(sections.first.subtypes.map(&:key)).to include(
      :incomplete_employee_side,
      :incomplete_manager_side,
      :pending_acknowledgements
    )
  end

  it "includes open feedback request responders when that subtype is expanded" do
    requestor = teammate
    subject = create(:teammate, :assigned_employee, organization: organization)
    fr = create(
      :feedback_request,
      company: organization,
      requestor_teammate: requestor,
      subject_of_feedback_teammate: subject,
      subject_line: "How is onboarding going?"
    )
    fr.feedback_request_responders.create!(teammate: teammate)

    sections = described_class.call(
      organization: organization,
      teammates: [teammate],
      expanded_subtype_keys: [:open_feedback_responses]
    )
    ogos = sections.find { |s| s.key == :ogos }
    fr_subtype = ogos.subtypes.find { |s| s.key == :open_feedback_responses }
    comments_subtype = ogos.subtypes.find { |s| s.key == :ogo_comments }

    expect(fr_subtype.count).to eq(1)
    expect(fr_subtype.expanded).to be(true)
    expect(fr_subtype.items.first.title).to eq("How is onboarding going?")
    expect(comments_subtype.expanded).to be(false)
    expect(comments_subtype.items).to be_empty
  end
end
