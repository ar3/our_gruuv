require 'rails_helper'
require 'ostruct'

RSpec.describe CommentPolicy, type: :policy do
  let(:organization) { create(:organization, :company) }
  let(:other_organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:ability) { create(:ability, organization: organization) }
  let(:aspiration) { create(:aspiration, organization: organization) }
  let(:comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }

  let(:teammate) { CompanyTeammate.create!(person: person, organization: organization) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: organization) }
  let(:other_org_teammate) { CompanyTeammate.create!(person: person, organization: other_organization) }

  let(:pundit_user) { OpenStruct.new(user: teammate, impersonating_teammate: nil) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }
  let(:pundit_user_other_org) { OpenStruct.new(user: other_org_teammate, impersonating_teammate: nil) }

  describe 'show?' do
    context 'when user can view the commentable object' do
      it 'allows access for assignments' do
        policy = CommentPolicy.new(pundit_user, comment)
        allow(Pundit).to receive(:policy).with(pundit_user, assignment).and_return(double(show?: true))
        expect(policy.show?).to be true
      end

      it 'allows access for abilities' do
        ability_comment = create(:comment, :on_ability, organization: organization, creator: person, commentable: ability)
        policy = CommentPolicy.new(pundit_user, ability_comment)
        allow(Pundit).to receive(:policy).with(pundit_user, ability).and_return(double(show?: true))
        expect(policy.show?).to be true
      end

      it 'allows access for aspirations' do
        aspiration_comment = create(:comment, :on_aspiration, organization: organization, creator: person, commentable: aspiration)
        policy = CommentPolicy.new(pundit_user, aspiration_comment)
        allow(Pundit).to receive(:policy).with(pundit_user, aspiration).and_return(double(show?: true))
        expect(policy.show?).to be true
      end
    end

    context 'when user cannot view the commentable object' do
      it 'denies access' do
        policy = CommentPolicy.new(pundit_user, comment)
        allow(Pundit).to receive(:policy).with(pundit_user, assignment).and_return(double(show?: false))
        expect(policy.show?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = CommentPolicy.new(pundit_user_admin, comment)
        expect(policy.show?).to be true
      end
    end

    context 'for nested comments' do
      let(:nested_comment) { create(:comment, commentable: comment, organization: organization, creator: person) }

      it 'checks root commentable permissions' do
        policy = CommentPolicy.new(pundit_user, nested_comment)
        allow(Pundit).to receive(:policy).with(pundit_user, assignment).and_return(double(show?: true))
        expect(policy.show?).to be true
      end
    end
  end

  describe 'create?' do
    let(:new_comment) { Comment.new(commentable: assignment, organization: organization) }

    context 'when user can view the commentable object' do
      it 'allows creation' do
        policy = CommentPolicy.new(pundit_user, new_comment)
        allow(Pundit).to receive(:policy).with(pundit_user, assignment).and_return(double(show?: true))
        expect(policy.create?).to be true
      end
    end

    context 'when user cannot view the commentable object' do
      it 'denies creation' do
        policy = CommentPolicy.new(pundit_user, new_comment)
        allow(Pundit).to receive(:policy).with(pundit_user, assignment).and_return(double(show?: false))
        expect(policy.create?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows creation' do
        policy = CommentPolicy.new(pundit_user_admin, new_comment)
        expect(policy.create?).to be true
      end
    end
  end

  describe 'update?' do
    context 'when user is the comment creator' do
      let(:creator_teammate) { CompanyTeammate.create!(person: person, organization: organization) }
      let(:pundit_user_creator) { OpenStruct.new(user: creator_teammate, impersonating_teammate: nil) }

      it 'allows update' do
        policy = CommentPolicy.new(pundit_user_creator, comment)
        expect(policy.update?).to be true
      end
    end

    context 'when user is not the comment creator' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: organization) }
      let(:pundit_user_other) { OpenStruct.new(user: other_teammate, impersonating_teammate: nil) }

      it 'denies update' do
        policy = CommentPolicy.new(pundit_user_other, comment)
        expect(policy.update?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows update' do
        policy = CommentPolicy.new(pundit_user_admin, comment)
        expect(policy.update?).to be true
      end
    end
  end

  describe 'resolve?' do
    context 'when user is the comment creator' do
      let(:creator_teammate) { CompanyTeammate.create!(person: person, organization: organization) }
      let(:pundit_user_creator) { OpenStruct.new(user: creator_teammate, impersonating_teammate: nil) }

      it 'allows resolve' do
        policy = CommentPolicy.new(pundit_user_creator, comment)
        expect(policy.resolve?).to be true
      end
    end

    context 'when user is not the comment creator' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: organization) }
      let(:pundit_user_other) { OpenStruct.new(user: other_teammate, impersonating_teammate: nil) }

      it 'denies resolve' do
        policy = CommentPolicy.new(pundit_user_other, comment)
        expect(policy.resolve?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows resolve' do
        policy = CommentPolicy.new(pundit_user_admin, comment)
        expect(policy.resolve?).to be true
      end
    end
  end

  describe 'unresolve?' do
    context 'when user is the comment creator' do
      let(:creator_teammate) { CompanyTeammate.create!(person: person, organization: organization) }
      let(:pundit_user_creator) { OpenStruct.new(user: creator_teammate, impersonating_teammate: nil) }

      it 'allows unresolve' do
        policy = CommentPolicy.new(pundit_user_creator, comment)
        expect(policy.unresolve?).to be true
      end
    end

    context 'when user is not the comment creator' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: organization) }
      let(:pundit_user_other) { OpenStruct.new(user: other_teammate, impersonating_teammate: nil) }

      it 'denies unresolve' do
        policy = CommentPolicy.new(pundit_user_other, comment)
        expect(policy.unresolve?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows unresolve' do
        policy = CommentPolicy.new(pundit_user_admin, comment)
        expect(policy.unresolve?).to be true
      end
    end
  end

  describe 'scope' do
    let!(:comment1) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }
    let!(:comment2) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }
    let!(:other_org_comment) { create(:comment, :on_assignment, organization: other_organization, creator: person, commentable: create(:assignment, company: other_organization)) }

    context 'when user is in the organization' do
      it 'returns comments for that organization' do
        policy = CommentPolicy::Scope.new(pundit_user, Comment)
        expect(policy.resolve).to include(comment1, comment2)
        expect(policy.resolve).not_to include(other_org_comment)
      end
    end

    context 'when user is admin' do
      it 'returns all comments' do
        policy = CommentPolicy::Scope.new(pundit_user_admin, Comment)
        expect(policy.resolve).to include(comment1, comment2, other_org_comment)
      end
    end
  end
end
