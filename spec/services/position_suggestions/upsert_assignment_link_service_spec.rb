# frozen_string_literal: true

require "rails_helper"

RSpec.describe PositionSuggestions::UpsertAssignmentLinkService do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level, level: "1.1") }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:assignment) { create(:assignment, company: organization, title: "Client Discovery") }
  let!(:position_assignment) do
    create(
      :position_assignment,
      position: position,
      assignment: assignment,
      assignment_type: "required",
      min_estimated_energy: 10,
      max_estimated_energy: 20
    )
  end
  let!(:suggestion) do
    create(:position_suggestion, position: position, organization: organization, opened_by: teammate)
  end

  before do
    allow(Comments::PostNotificationJob).to receive(:perform_and_get_result)
  end

  it "creates an update link and a system root comment when type changes" do
    result = described_class.call(
      suggestion: suggestion,
      assignment: assignment,
      attributes: {
        action: "update",
        assignment_type: "suggested",
        min_estimated_energy: 10,
        max_estimated_energy: 20
      },
      modified_by: teammate
    )

    expect(result).to be_ok
    link = result.value
    expect(link.action).to eq("update")
    expect(link.assignment_type).to eq("suggested")
    expect(position_assignment.reload.assignment_type).to eq("required")

    comment = Comment.for_position_suggestion(suggestion).for_suggestion_thread_subject(link).root_comments.first
    expect(comment).to be_present
    expect(comment.body).to include("suggested Assignment association changes")
    expect(comment.body).to include("Type:")
    expect(comment.commentable).to eq(assignment)
  end

  it "creates a remove link while retaining type and energy" do
    result = described_class.call(
      suggestion: suggestion,
      assignment: assignment,
      attributes: {
        action: "remove",
        assignment_type: "required",
        min_estimated_energy: 10,
        max_estimated_energy: 20
      },
      modified_by: teammate
    )

    expect(result).to be_ok
    expect(result.value.action).to eq("remove")
    expect(position.assignments.exists?(id: assignment.id)).to be true
    comment = Comment.for_suggestion_thread_subject(result.value).root_comments.first
    expect(comment.body).to include("suggested removing Assignment")
  end

  it "creates an add link for an Assignment not on the Position" do
    other = create(:assignment, company: organization, title: "Other Work")

    result = described_class.call(
      suggestion: suggestion,
      assignment: other,
      attributes: {
        action: "add",
        assignment_type: "suggested",
        min_estimated_energy: 5,
        max_estimated_energy: 15
      },
      modified_by: teammate
    )

    expect(result).to be_ok
    link = result.value
    expect(link.action).to eq("add")
    expect(position.assignments.exists?(id: other.id)).to be false
    comment = Comment.for_suggestion_thread_subject(link).root_comments.first
    expect(comment.body).to include("suggested adding Assignment")
  end

  it "rejects an update with no changes from live MAAP" do
    result = described_class.call(
      suggestion: suggestion,
      assignment: assignment,
      attributes: {
        action: "update",
        assignment_type: "required",
        min_estimated_energy: 10,
        max_estimated_energy: 20
      },
      modified_by: teammate
    )

    expect(result).not_to be_ok
    expect(Array(result.error).join).to include("No changes from current MAAP")
  end

  it "rejects adding an Assignment already on the Position" do
    result = described_class.call(
      suggestion: suggestion,
      assignment: assignment,
      attributes: {
        action: "add",
        assignment_type: "required",
        min_estimated_energy: nil,
        max_estimated_energy: nil
      },
      modified_by: teammate
    )

    expect(result).not_to be_ok
    expect(Array(result.error).join).to include("already on this position")
  end

  it "posts a reply when bag values change" do
    described_class.call(
      suggestion: suggestion,
      assignment: assignment,
      attributes: {
        action: "update",
        assignment_type: "suggested",
        min_estimated_energy: 10,
        max_estimated_energy: 20
      },
      modified_by: teammate
    )
    link = suggestion.assignment_links.find_by!(assignment: assignment)

    expect do
      described_class.call(
        suggestion: suggestion,
        assignment: assignment,
        attributes: {
          action: "update",
          assignment_type: "suggested",
          min_estimated_energy: 15,
          max_estimated_energy: 25
        },
        modified_by: teammate
      )
    end.to change(Comment, :count).by(1)

    reply = Comment.where(commentable: Comment.for_suggestion_thread_subject(link).root_comments.first).last
    expect(reply.body).to include("updated Assignment association suggestions")
    expect(reply.body).to include("Min energy:")
  end
end
