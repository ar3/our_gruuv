# frozen_string_literal: true

require "rails_helper"

RSpec.describe PositionSuggestions::UpsertAssignmentDraftService do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level, level: "1.1") }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:assignment) do
    create(
      :assignment,
      company: organization,
      title: "Client Discovery",
      tagline: "Discover needs",
      required_activities: "Interview stakeholders",
      handbook: "See playbook"
    )
  end
  let!(:position_assignment) { create(:position_assignment, position: position, assignment: assignment) }
  let!(:outcome) do
    create(:assignment_outcome, assignment: assignment, description: "Capture priorities", outcome_type: "quantitative")
  end
  let!(:suggestion) do
    create(:position_suggestion, position: position, organization: organization, opened_by: teammate)
  end

  before do
    allow(Comments::PostNotificationJob).to receive(:perform_and_get_result)
  end

  it "creates a draft, outcomes set, and a system root comment with live diffs" do
    result = described_class.call(
      suggestion: suggestion,
      source_assignment: assignment,
      attributes: {
        title: "Client Discovery Plus",
        tagline: "Discover needs deeply",
        required_activities: assignment.required_activities,
        handbook: assignment.handbook
      },
      outcomes: [
        { description: "Capture priorities", outcome_type: "quantitative" },
        { description: "Share a brief", outcome_type: "sentiment" }
      ],
      modified_by: teammate
    )

    expect(result).to be_ok
    draft = result.value
    expect(draft.title).to eq("Client Discovery Plus")
    expect(draft.outcomes.count).to eq(2)

    comment = Comment.for_position_suggestion(suggestion).for_suggestion_thread_subject(draft).root_comments.first
    expect(comment).to be_present
    expect(comment.body).to include("suggested Assignment field changes")
    expect(comment.body).to include("Title:")
    expect(comment.body).to include("Outcomes:")
    expect(comment.commentable).to eq(assignment)
  end

  it "posts a reply with only fields changed vs previous draft" do
    described_class.call(
      suggestion: suggestion,
      source_assignment: assignment,
      attributes: {
        title: "Client Discovery Plus",
        tagline: assignment.tagline,
        required_activities: assignment.required_activities,
        handbook: assignment.handbook
      },
      outcomes: [{ description: "Capture priorities", outcome_type: "quantitative" }],
      modified_by: teammate
    )

    draft = suggestion.assignment_drafts.find_by!(source_assignment: assignment)

    expect do
      described_class.call(
        suggestion: suggestion,
        source_assignment: assignment,
        attributes: {
          title: "Client Discovery Plus",
          tagline: "New tagline only",
          required_activities: assignment.required_activities,
          handbook: assignment.handbook
        },
        outcomes: [{ description: "Capture priorities", outcome_type: "quantitative" }],
        modified_by: teammate
      )
    end.to change(Comment, :count).by(1)

    reply = Comment.where(commentable: Comment.for_suggestion_thread_subject(draft).root_comments.first).last
    expect(reply.body).to include("updated Assignment field suggestions")
    expect(reply.body).to include("Tagline:")
    expect(reply.body).not_to include("Title:")
  end

  it "rejects a first save with no changes from live MAAP" do
    result = described_class.call(
      suggestion: suggestion,
      source_assignment: assignment,
      attributes: {
        title: assignment.title,
        tagline: assignment.tagline,
        required_activities: assignment.required_activities,
        handbook: assignment.handbook
      },
      outcomes: [{ description: "Capture priorities", outcome_type: "quantitative" }],
      modified_by: teammate
    )

    expect(result).not_to be_ok
    expect(Array(result.error).join).to include("No changes from current MAAP")
  end
end
