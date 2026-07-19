require 'rails_helper'

RSpec.describe "Organizations::Comments", type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }

  before do
    create(:teammate, person: person, organization: organization)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/comments" do
    let!(:root_comment1) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment, body: 'Unresolved comment 1') }
    let!(:root_comment2) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment, body: 'Unresolved comment 2') }
    let!(:resolved_comment) { create(:comment, :resolved, :on_assignment, organization: organization, creator: person, commentable: assignment, body: 'Resolved comment unique') }

    it "renders the index page" do
      get organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id)
      expect(response).to have_http_status(:success)
    end

    context "with show_resolved=false (default)" do
      it "excludes resolved comments" do
        get organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id)
        expect(response.body).to include('Unresolved comment 1')
        expect(response.body).to include('Unresolved comment 2')
        expect(response.body).not_to include('Resolved comment unique')
      end
    end

    context "with show_resolved=true" do
      it "includes resolved comments" do
        get organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id, show_resolved: 'true')
        expect(response.body).to include('Unresolved comment 1')
        expect(response.body).to include('Unresolved comment 2')
        expect(response.body).to include('Resolved comment unique')
      end
    end
  end

  describe "POST /organizations/:organization_id/comments" do
    it "creates a new comment" do
      expect {
        post organization_comments_path(organization), params: {
          comment: {
            body: 'New comment',
            commentable_type: 'Assignment',
            commentable_id: assignment.id
          }
        }
      }.to change(Comment, :count).by(1)
    end

    it "redirects to the comments index" do
      post organization_comments_path(organization), params: {
        comment: {
          body: 'New comment',
          commentable_type: 'Assignment',
          commentable_id: assignment.id
        }
      }
      expect(response).to redirect_to(organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id))
    end
  end

  describe "PATCH /organizations/:organization_id/comments/:id/resolve" do
    let!(:child_comment) { create(:comment, commentable: comment, organization: organization, creator: person) }

    it "resolves the comment" do
      patch resolve_organization_comment_path(organization, comment)
      expect(comment.reload.resolved_at).not_to be_nil
    end

    it "cascades resolution to descendants" do
      patch resolve_organization_comment_path(organization, comment)
      expect(child_comment.reload.resolved_at).not_to be_nil
    end

    it "redirects to comments index" do
      patch resolve_organization_comment_path(organization, comment)
      expect(response).to redirect_to(organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id))
    end

    it "preserves show_resolved parameter in redirect" do
      patch resolve_organization_comment_path(organization, comment, show_resolved: 'true')
      expect(response).to redirect_to(organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id, show_resolved: 'true'))
    end
  end

  describe "PATCH /organizations/:organization_id/comments/:id/unresolve" do
    let(:resolved_comment) { create(:comment, :resolved, :on_assignment, organization: organization, creator: person, commentable: assignment) }
    let!(:child_comment) { create(:comment, :resolved, commentable: resolved_comment, organization: organization, creator: person) }

    it "unresolves the comment" do
      patch unresolve_organization_comment_path(organization, resolved_comment)
      expect(resolved_comment.reload.resolved_at).to be_nil
    end

    it "does not affect descendants (independent behavior)" do
      patch unresolve_organization_comment_path(organization, resolved_comment)
      expect(child_comment.reload.resolved_at).not_to be_nil
    end

    it "redirects to comments index" do
      patch unresolve_organization_comment_path(organization, resolved_comment)
      expect(response).to redirect_to(organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id))
    end

    it "preserves show_resolved parameter in redirect" do
      patch unresolve_organization_comment_path(organization, resolved_comment, show_resolved: 'true')
      expect(response).to redirect_to(organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id, show_resolved: 'true'))
    end
  end

  describe "PATCH /organizations/:organization_id/comments/:id" do
    it "updates the comment" do
      patch organization_comment_path(organization, comment), params: {
        comment: { body: 'Updated comment' }
      }
      expect(comment.reload.body).to eq('Updated comment')
    end

    it "redirects to comments index" do
      patch organization_comment_path(organization, comment), params: {
        comment: { body: 'Updated comment' }
      }
      expect(response).to redirect_to(organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id))
    end
  end

  describe "observation comments" do
    let(:observer) { create(:person) }
    let!(:observer_teammate) { create(:company_teammate, person: observer, organization: organization) }
    let(:observee) { CompanyTeammate.find_by!(person: person, organization: organization) }
    let(:observation) do
      obs = build(:observation, :published, :observed_only, observer: observer, company: organization)
      obs.observees = []
      obs.observees.build(teammate: observee)
      obs.save!
      obs
    end

    it "creates a comment on a published observation" do
      expect {
        post organization_comments_path(organization), params: {
          comment: {
            body: 'Thanks for the context',
            commentable_type: 'Observation',
            commentable_id: observation.id
          }
        }
      }.to change(Comment, :count).by(1)

      expect(response).to redirect_to(organization_comments_path(organization, commentable_type: 'Observation', commentable_id: observation.id))
      expect(Comment.last.commentable).to eq(observation)
    end

    it "does not enqueue MAAP Slack notification for observation comments" do
      expect(Comments::PostNotificationJob).not_to receive(:perform_and_get_result)

      post organization_comments_path(organization), params: {
        comment: {
          body: 'No Slack please',
          commentable_type: 'Observation',
          commentable_id: observation.id
        }
      }
    end

    it "rejects comments on draft observations" do
      draft = build(:observation, observer: observer, company: organization, published_at: nil, story: 'Draft')
      draft.observees = []
      draft.observees.build(teammate: observee)
      draft.save!(validate: false)

      expect {
        post organization_comments_path(organization), params: {
          comment: {
            body: 'Should fail',
            commentable_type: 'Observation',
            commentable_id: draft.id
          }
        }
      }.not_to change(Comment, :count)
    end

    it "allows the creator to delete an observation comment" do
      ogo_comment = create(:comment, organization: organization, creator: person, commentable: observation)

      expect {
        delete organization_comment_path(organization, ogo_comment)
      }.to change(Comment, :count).by(-1)
    end

    it "shows comments entry point on the observation show page" do
      create(:comment, organization: organization, creator: person, commentable: observation, body: 'Visible on show')

      get organization_observation_path(organization, observation)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('View Comments')
    end
  end
end
