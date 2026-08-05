require "rails_helper"

RSpec.describe "Organizations::PositionSuggestions", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level, level: "1.1") }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:assignment) { create(:assignment, company: organization, title: "Client Discovery", tagline: "Discover needs") }
  let(:ability) { create(:ability, company: organization, name: "Communication") }

  before do
    create(:position_assignment, position: position, assignment: assignment, assignment_type: "required")
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/position_suggestions" do
    it "renders the beta index" do
      get organization_position_suggestions_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Position Suggestions")
      expect(response.body).to include("Beta")
      expect(response.body).to include(position.display_name)
    end
  end

  describe "POST create + show flow" do
    it "opens a round and shows assignments with milestone controls and action panels" do
      expect do
        post organization_position_suggestions_path(organization), params: { position_id: position.id }
      end.to change(PositionSuggestion, :count).by(1)

      suggestion = PositionSuggestion.last
      expect(response).to redirect_to(organization_position_suggestion_path(organization, suggestion))

      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Client Discovery")
      expect(response.body).to include("Communication")
      expect(response.body).to include("Beta")
      expect(response.body).to include("Open round")
      expect(response.body).to include("Suggestion summary")
      expect(response.body).to include("done making suggestions for this round")
      expect(response.body).to include("I actually don")
      expect(response.body).to include("MAAP Managers Review Suggestions")
      expect(response.body).to include("Only MAAP managers can perform these operations")
      expect(response.body).to include("round-actions-top")
      expect(response.body).to include("round-actions-bottom")
      expect(response.body).to include("Comments")
      expect(response.body).to include('data-bs-toggle="popover"')
      expect(response.body).to include(organization_ability_path(organization, ability))
      expect(response.body).to include('aria-label="Suggested milestone for Communication"')
    end
  end

  describe "milestone suggestion and participation" do
    let!(:suggestion) do
      PositionSuggestions::FindOrOpenService.call(
        position: position,
        organization: organization,
        opened_by: teammate
      ).value
    end
    let(:assignment_ability) { assignment.assignment_abilities.first }

    it "upserts a bag-scoped milestone suggestion" do
      allow(Comments::PostNotificationJob).to receive(:perform_and_get_result)

      expect do
        patch upsert_milestone_organization_position_suggestion_path(organization, suggestion),
              params: {
                milestoneable_type: "AssignmentAbility",
                milestoneable_id: assignment_ability.id,
                suggested_milestone_level: 3
              }
      end.to change(Comment, :count).by(1)

      expect(response).to redirect_to(organization_position_suggestion_path(organization, suggestion, anchor: "assignment-#{assignment.id}"))
      milestone = suggestion.milestones.find_by!(milestoneable: assignment_ability)
      expect(milestone.suggested_milestone_level).to eq(3)
      expect(assignment_ability.reload.milestone_level).to eq(2)

      comment = Comment.for_position_suggestion(suggestion).for_suggestion_thread_subject(assignment_ability).root_comments.first
      expect(comment.body).to include("Milestone 3")
      expect(comment.commentable).to eq(assignment)
    end

    it "blocks done contributing before any suggestions" do
      patch update_participation_organization_position_suggestion_path(organization, suggestion),
            params: { participation_status: "done_contributing" }

      expect(response).to redirect_to(organization_position_suggestion_path(organization, suggestion))
      expect(suggestion.participant_for(teammate).reload).to be_active
    end

    it "marks the participant done contributing after a free-text comment" do
      Comment.create!(
        commentable: assignment,
        organization: organization,
        creator: person,
        position_suggestion: suggestion,
        body: "Needs clearer outcomes"
      )

      patch update_participation_organization_position_suggestion_path(organization, suggestion),
            params: { participation_status: "done_contributing" }

      expect(response).to redirect_to(organization_position_suggestions_path(organization))
      expect(suggestion.participant_for(teammate).reload).to be_done_contributing
    end

    it "adds a round-scoped assignment comment" do
      expect do
        post create_comment_organization_position_suggestion_path(organization, suggestion),
             params: {
               commentable_type: "Assignment",
               commentable_id: assignment.id,
               comment: { body: "Milestone should be M3 for coaching readiness." }
             }
      end.to change(Comment, :count).by(1)

      comment = Comment.last
      expect(comment.position_suggestion_id).to eq(suggestion.id)
      expect(comment.commentable).to eq(assignment)
    end
  end

  describe "MAAP close" do
    let(:maap_person) { create(:person) }
    let!(:maap_teammate) do
      create(:company_teammate, person: maap_person, organization: organization, can_manage_maap: true)
    end
    let!(:suggestion) do
      PositionSuggestions::FindOrOpenService.call(
        position: position,
        organization: organization,
        opened_by: teammate
      ).value
    end

    it "lets a MAAP manager complete when no unresolved active roots remain" do
      sign_in_as_teammate_for_request(maap_person, organization)

      patch close_organization_position_suggestion_path(organization, suggestion)

      expect(response).to redirect_to(organization_position_suggestions_path(organization))
      expect(suggestion.reload).to be_completed
    end

    it "blocks complete when an active participant has an unresolved free-text root comment" do
      Comment.create!(
        commentable: assignment,
        organization: organization,
        creator: person,
        position_suggestion: suggestion,
        body: "Please lower this milestone"
      )
      sign_in_as_teammate_for_request(maap_person, organization)

      patch close_organization_position_suggestion_path(organization, suggestion)

      expect(response).to redirect_to(organization_position_suggestion_path(organization, suggestion))
      expect(suggestion.reload).to be_open
    end

    it "blocks complete for unresolved ability-milestone system roots" do
      aa = assignment.assignment_abilities.first
      Comment.create!(
        commentable: assignment,
        organization: organization,
        creator: person,
        position_suggestion: suggestion,
        suggestion_thread_subject: aa,
        body: "system milestone thread"
      )
      sign_in_as_teammate_for_request(maap_person, organization)

      patch close_organization_position_suggestion_path(organization, suggestion)

      expect(response).to redirect_to(organization_position_suggestion_path(organization, suggestion))
      expect(suggestion.reload).to be_open
      expect(suggestion.can_complete?).to be false
    end

    it "shows the complete action disabled with a warning when unresolved roots remain" do
      Comment.create!(
        commentable: assignment,
        organization: organization,
        creator: person,
        position_suggestion: suggestion,
        body: "Please lower this milestone"
      )
      sign_in_as_teammate_for_request(maap_person, organization)

      get organization_position_suggestion_path(organization, suggestion)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Mark this round complete")
      expect(response.body).to include("bi-exclamation-triangle-fill")
      expect(response.body).to include("including ability-milestone suggestion threads")
      expect(response.body).to include("bi-arrow-right-circle-fill")
      expect(response.body).not_to include(close_organization_position_suggestion_path(organization, suggestion))
    end

    it "lets a MAAP manager resolve free-text comments from the process list path" do
      comment = Comment.create!(
        commentable: assignment,
        organization: organization,
        creator: person,
        position_suggestion: suggestion,
        body: "Please lower this milestone"
      )
      sign_in_as_teammate_for_request(maap_person, organization)
      return_to = organization_position_suggestion_path(organization, suggestion)

      patch resolve_organization_comment_path(organization, comment, return_to: return_to)

      expect(response).to redirect_to(return_to)
      expect(comment.reload).to be_resolved
    end
  end
end
