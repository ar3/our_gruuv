require "rails_helper"

RSpec.describe PositionSuggestions::NotifyMilestoneSuggestionService do
  let(:organization) { create(:organization) }
  let(:person) { create(:person, first_name: "Alex", last_name: "Rivera") }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level, level: "1.1") }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:assignment) { create(:assignment, company: organization, title: "Client Discovery") }
  let(:ability) { create(:ability, company: organization, name: "Communication") }
  let!(:assignment_ability) { create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2) }
  let(:suggestion) do
    PositionSuggestions::FindOrOpenService.call(
      position: position,
      organization: organization,
      opened_by: teammate
    ).value
  end

  before do
    create(:position_assignment, position: position, assignment: assignment, assignment_type: "required")
    allow(Comments::PostNotificationJob).to receive(:perform_and_get_result)
  end

  it "creates a session-scoped root comment on the assignment with milestone language" do
    expect do
      described_class.call(
        suggestion: suggestion,
        assignment_ability: assignment_ability,
        suggested_milestone_level: 3,
        modified_by: teammate
      )
    end.to change(Comment, :count).by(1)

    root = Comment.last
    expect(root.commentable).to eq(assignment)
    expect(root.position_suggestion).to eq(suggestion)
    expect(root.suggestion_thread_subject).to eq(assignment_ability)
    expect(root.creator).to eq(person)
    expect(root.body).to include("suggested Milestone 3 (Expert)")
    expect(root.body).to include("Ability Communication")
    expect(root.body).to include("Assignment Client Discovery")
    expect(root.body).to include("Position #{position.display_name}")
    expect(Comments::PostNotificationJob).to have_received(:perform_and_get_result).with(root.id)
  end

  it "replies under the same root on later suggestions and reopens a resolved root" do
    described_class.call(
      suggestion: suggestion,
      assignment_ability: assignment_ability,
      suggested_milestone_level: 3,
      modified_by: teammate
    )
    root = Comment.for_suggestion_thread_subject(assignment_ability).root_comments.first
    root.resolve!

    expect do
      described_class.call(
        suggestion: suggestion,
        assignment_ability: assignment_ability,
        suggested_milestone_level: 4,
        modified_by: teammate
      )
    end.to change(Comment, :count).by(1)

    reply = Comment.order(:id).last
    expect(reply.commentable).to eq(root)
    expect(reply.position_suggestion).to eq(suggestion)
    expect(reply.body).to include("Milestone 4 (Coach)")
    expect(root.reload).not_to be_resolved
    expect(Comments::PostNotificationJob).to have_received(:perform_and_get_result).with(root.id).at_least(:twice)
  end
end
