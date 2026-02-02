require 'rails_helper'

RSpec.describe Organizations::CommentsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }

  before do
    create(:teammate, person: person, organization: organization)
    sign_in_as_teammate(person, organization)
  end

  describe 'GET #index' do
    let!(:root_comment1) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }
    let!(:root_comment2) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }
    let!(:resolved_comment) { create(:comment, :resolved, :on_assignment, organization: organization, creator: person, commentable: assignment) }

    it 'renders the index template' do
      get :index, params: { organization_id: organization.id, commentable_type: 'Assignment', commentable_id: assignment.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:index)
    end

    it 'assigns root comments' do
      get :index, params: { organization_id: organization.id, commentable_type: 'Assignment', commentable_id: assignment.id }
      expect(assigns(:root_comments)).to include(root_comment1, root_comment2)
    end

    it 'builds comments tree' do
      get :index, params: { organization_id: organization.id, commentable_type: 'Assignment', commentable_id: assignment.id }
      expect(assigns(:comments_by_parent)).to be_a(Hash)
    end

    context 'with show_resolved=false (default)' do
      it 'excludes resolved comments' do
        get :index, params: { organization_id: organization.id, commentable_type: 'Assignment', commentable_id: assignment.id }
        expect(assigns(:root_comments)).to include(root_comment1, root_comment2)
        expect(assigns(:root_comments)).not_to include(resolved_comment)
        expect(assigns(:show_resolved)).to be false
      end
    end

    context 'with show_resolved=true' do
      it 'includes resolved comments' do
        get :index, params: { organization_id: organization.id, commentable_type: 'Assignment', commentable_id: assignment.id, show_resolved: 'true' }
        expect(assigns(:root_comments)).to include(root_comment1, root_comment2, resolved_comment)
        expect(assigns(:show_resolved)).to be true
      end
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      it 'creates a new comment' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            comment: {
              body: 'New comment',
              commentable_type: 'Assignment',
              commentable_id: assignment.id
            }
          }
        }.to change(Comment, :count).by(1)
      end

      it 'redirects to comments index' do
        post :create, params: {
          organization_id: organization.id,
          comment: {
            body: 'New comment',
            commentable_type: 'Assignment',
            commentable_id: assignment.id
          }
        }
        expect(response).to redirect_to(organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id))
      end

      it 'sets the creator' do
        post :create, params: {
          organization_id: organization.id,
          comment: {
            body: 'New comment',
            commentable_type: 'Assignment',
            commentable_id: assignment.id
          }
        }
        expect(Comment.last.creator).to eq(person)
      end
    end

    context 'with invalid parameters' do
      it 'does not create a comment' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            comment: {
              body: '',
              commentable_type: 'Assignment',
              commentable_id: assignment.id
            }
          }
        }.not_to change(Comment, :count)
      end

      it 're-renders the index template' do
        post :create, params: {
          organization_id: organization.id,
          comment: {
            body: '',
            commentable_type: 'Assignment',
            commentable_id: assignment.id
          }
        }
        expect(response).to render_template(:index)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'creating nested comment' do
      it 'creates a reply to a comment' do
        # Ensure parent comment exists before counting
        parent_comment = comment
        
        expect {
          post :create, params: {
            organization_id: organization.id,
            comment: {
              body: 'Reply comment',
              commentable_type: 'Comment',
              commentable_id: parent_comment.id
            }
          }
        }.to change(Comment, :count).by(1)
        
        reply = Comment.last
        expect(reply.commentable).to eq(parent_comment)
      end
    end
  end

  describe 'PATCH #update' do
    context 'with valid parameters' do
      it 'updates the comment' do
        patch :update, params: {
          organization_id: organization.id,
          id: comment.id,
          comment: { body: 'Updated comment' }
        }
        expect(comment.reload.body).to eq('Updated comment')
      end

      it 'redirects to comments index' do
        patch :update, params: {
          organization_id: organization.id,
          id: comment.id,
          comment: { body: 'Updated comment' }
        }
        expect(response).to redirect_to(organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id))
      end
    end

    context 'with invalid parameters' do
      it 'does not update the comment' do
        original_body = comment.body
        patch :update, params: {
          organization_id: organization.id,
          id: comment.id,
          comment: { body: '' }
        }
        expect(comment.reload.body).to eq(original_body)
      end

      it 're-renders the index template' do
        patch :update, params: {
          organization_id: organization.id,
          id: comment.id,
          comment: { body: '' }
        }
        expect(response).to render_template(:index)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH #resolve' do
    let!(:child_comment) { create(:comment, commentable: comment, organization: organization, creator: person) }

    it 'resolves the comment' do
      patch :resolve, params: { organization_id: organization.id, id: comment.id }
      expect(comment.reload.resolved_at).not_to be_nil
    end

    it 'cascades resolution to descendants' do
      patch :resolve, params: { organization_id: organization.id, id: comment.id }
      expect(child_comment.reload.resolved_at).not_to be_nil
    end

    it 'redirects to comments index' do
      patch :resolve, params: { organization_id: organization.id, id: comment.id }
      expect(response).to redirect_to(organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id))
    end

    it 'preserves show_resolved parameter in redirect' do
      patch :resolve, params: { organization_id: organization.id, id: comment.id, show_resolved: 'true' }
      expect(response).to redirect_to(organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id, show_resolved: 'true'))
    end
  end

  describe 'PATCH #unresolve' do
    let(:resolved_comment) { create(:comment, :resolved, :on_assignment, organization: organization, creator: person, commentable: assignment) }
    let!(:child_comment) { create(:comment, :resolved, commentable: resolved_comment, organization: organization, creator: person) }

    it 'unresolves the comment' do
      patch :unresolve, params: { organization_id: organization.id, id: resolved_comment.id }
      expect(resolved_comment.reload.resolved_at).to be_nil
    end

    it 'does not affect descendants (independent behavior)' do
      patch :unresolve, params: { organization_id: organization.id, id: resolved_comment.id }
      expect(child_comment.reload.resolved_at).not_to be_nil
    end

    it 'redirects to comments index' do
      patch :unresolve, params: { organization_id: organization.id, id: resolved_comment.id }
      expect(response).to redirect_to(organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id))
    end

    it 'preserves show_resolved parameter in redirect' do
      patch :unresolve, params: { organization_id: organization.id, id: resolved_comment.id, show_resolved: 'true' }
      expect(response).to redirect_to(organization_comments_path(organization, commentable_type: 'Assignment', commentable_id: assignment.id, show_resolved: 'true'))
    end
  end
end
