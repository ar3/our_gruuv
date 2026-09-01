# frozen_string_literal: true

require "rails_helper"

RSpec.describe PositionSuggestions::ProcessMilestoneDecisionService do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:maap_teammate) { create(:company_teammate, organization: organization, can_manage_maap: true) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level, level: "1.1") }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:assignment) { create(:assignment, company: organization, title: "Client Discovery") }
  let(:ability) { create(:ability, company: organization, name: "Communication") }
  let!(:position_assignment) { create(:position_assignment, position: position, assignment: assignment) }
  let!(:assignment_ability) do
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
  end
  let!(:suggestion) do
    create(:position_suggestion, position: position, organization: organization, opened_by: teammate)
  end
  let!(:milestone) do
    create(
      :position_suggestion_milestone,
      position_suggestion: suggestion,
      milestoneable: assignment_ability,
      last_modified_by: teammate,
      suggested_milestone_level: 3
    )
  end

  before do
    allow(Comments::PostNotificationJob).to receive(:perform_and_get_result)
  end

  it "accepts and applies the suggested milestone level to live MAAP" do
    Comment.create!(
      commentable: assignment,
      organization: organization,
      creator: teammate.person,
      position_suggestion: suggestion,
      suggestion_thread_subject: assignment_ability,
      body: "Suggested Milestone 3"
    )

    result = described_class.call(
      suggestion: suggestion,
      milestone: milestone,
      decision: "accepted",
      processed_by: maap_teammate
    )

    expect(result).to be_ok
    expect(assignment_ability.reload.milestone_level).to eq(3)
    expect(milestone.reload).to be_accepted
    expect(milestone.processed_by).to eq(maap_teammate)
    root = Comment.for_suggestion_thread_subject(assignment_ability).root_comments.first
    expect(root).to be_resolved
    expect(Comment.where(commentable: root).last.body).to include("accepted this suggestion")
  end

  it "rejects without changing live MAAP" do
    result = described_class.call(
      suggestion: suggestion,
      milestone: milestone,
      decision: "rejected",
      processed_by: maap_teammate
    )

    expect(result).to be_ok
    expect(assignment_ability.reload.milestone_level).to eq(2)
    expect(milestone.reload).to be_rejected
  end

  it "rejects processing an already processed milestone" do
    milestone.update!(decision: "accepted", processed_by: maap_teammate, processed_at: Time.current)

    result = described_class.call(
      suggestion: suggestion,
      milestone: milestone,
      decision: "rejected",
      processed_by: maap_teammate
    )

    expect(result).not_to be_ok
    expect(Array(result.error).join).to include("already processed")
  end
end
