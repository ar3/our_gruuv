require 'rails_helper'

RSpec.describe Comment, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:ability) { create(:ability, company: organization) }
  let(:aspiration) { create(:aspiration, company: organization) }
  
  let(:comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }

  describe 'associations' do
    it { should belong_to(:commentable) }
    it { should belong_to(:organization) }
    it { should belong_to(:creator).class_name('Person') }
    it { should have_many(:comments).dependent(:destroy) }
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(comment).to be_valid
    end

    it 'requires body' do
      comment.body = nil
      expect(comment).not_to be_valid
      expect(comment.errors[:body]).to include("can't be blank")
    end

    it 'requires organization' do
      comment.organization = nil
      expect(comment).not_to be_valid
    end

    it 'requires creator' do
      comment.creator = nil
      expect(comment).not_to be_valid
    end

    it 'requires commentable' do
      comment.commentable = nil
      expect(comment).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:resolved_comment) { create(:comment, :resolved, :on_assignment, organization: organization, creator: person, commentable: assignment) }
    let!(:unresolved_comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }

    describe '.unresolved' do
      it 'returns only unresolved comments' do
        expect(Comment.unresolved).to include(unresolved_comment)
        expect(Comment.unresolved).not_to include(resolved_comment)
      end
    end

    describe '.resolved' do
      it 'returns only resolved comments' do
        expect(Comment.resolved).to include(resolved_comment)
        expect(Comment.resolved).not_to include(unresolved_comment)
      end
    end

    describe '.for_commentable' do
      let(:other_assignment) { create(:assignment, company: organization) }
      let!(:other_comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: other_assignment) }

      it 'returns comments for the specified commentable' do
        comments = Comment.for_commentable(assignment)
        expect(comments).to include(comment, unresolved_comment, resolved_comment)
        expect(comments).not_to include(other_comment)
      end
    end

    describe '.root_comments' do
      let!(:nested_comment) { create(:comment, commentable: comment, organization: organization, creator: person) }

      it 'returns only root comments (not nested)' do
        root_comments = Comment.root_comments
        expect(root_comments).to include(comment)
        expect(root_comments).not_to include(nested_comment)
      end
    end

    describe '.ordered' do
      let!(:older_comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment, created_at: 2.days.ago) }
      let!(:newer_comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment, created_at: 1.day.ago) }

      it 'orders comments by created_at ascending' do
        ordered = Comment.for_commentable(assignment).ordered.to_a
        older_index = ordered.index(older_comment)
        newer_index = ordered.index(newer_comment)
        expect(older_index).to be < newer_index
      end
    end
  end

  describe 'instance methods' do
    describe '#resolved?' do
      it 'returns true when resolved_at is present' do
        comment.resolved_at = Time.current
        expect(comment.resolved?).to be true
      end

      it 'returns false when resolved_at is nil' do
        comment.resolved_at = nil
        expect(comment.resolved?).to be false
      end
    end

    describe '#root_comment?' do
      it 'returns true for root comments' do
        expect(comment.root_comment?).to be true
      end

      it 'returns false for nested comments' do
        nested_comment = create(:comment, commentable: comment, organization: organization, creator: person)
        expect(nested_comment.root_comment?).to be false
      end
    end

    describe '#slack_url' do
      let(:slack_channel) { create(:third_party_object, :slack_channel, organization: organization) }
      
      before do
        # Create the association on the company (organization is already a Company)
        company_record = organization.becomes(Company)
        company_record.third_party_object_associations.create!(
          third_party_object: slack_channel,
          association_type: 'maap_object_comment_channel'
        )
        # Reload to ensure association is loaded
        organization.reload
        # Stub calculated_slack_config
        allow_any_instance_of(Organization).to receive(:calculated_slack_config).and_return(double(workspace_url: 'https://workspace.slack.com'))
        comment.update_column(:slack_message_id, '1234567890.123456')
      end

      it 'returns Slack URL when slack_message_id is present' do
        # The organization should be a Company and have the association
        company = comment.organization.root_company || comment.organization
        expect(company.is_a?(Company) || company.company?).to be true
        expect(comment.slack_url).to be_present
        expect(comment.slack_url).to include('slack.com')
      end

      it 'returns nil when slack_message_id is not present' do
        comment.update_column(:slack_message_id, nil)
        expect(comment.slack_url).to be_nil
      end
    end

    describe '#resolve!' do
      let!(:child_comment) { create(:comment, commentable: comment, organization: organization, creator: person) }
      let!(:grandchild_comment) { create(:comment, commentable: child_comment, organization: organization, creator: person) }

      it 'sets resolved_at on the comment' do
        expect { comment.resolve! }.to change { comment.reload.resolved_at }.from(nil)
      end

      it 'cascades resolution to all descendants' do
        comment.resolve!
        expect(child_comment.reload.resolved_at).not_to be_nil
        expect(grandchild_comment.reload.resolved_at).not_to be_nil
      end

      it 'uses a transaction' do
        expect(Comment).to receive(:transaction).and_call_original
        comment.resolve!
      end
    end

    describe '#unresolve!' do
      let(:resolved_comment) { create(:comment, :resolved, :on_assignment, organization: organization, creator: person, commentable: assignment) }
      let!(:child_comment) { create(:comment, :resolved, commentable: resolved_comment, organization: organization, creator: person) }

      it 'clears resolved_at on the comment' do
        expect { resolved_comment.unresolve! }.to change { resolved_comment.reload.resolved_at }.to(nil)
      end

      it 'does not affect descendants (independent behavior)' do
        resolved_comment.unresolve!
        expect(child_comment.reload.resolved_at).not_to be_nil
      end
    end

    describe '#descendants' do
      let!(:child1) { create(:comment, commentable: comment, organization: organization, creator: person) }
      let!(:child2) { create(:comment, commentable: comment, organization: organization, creator: person) }
      let!(:grandchild) { create(:comment, commentable: child1, organization: organization, creator: person) }

      it 'returns all nested comments recursively' do
        descendants = comment.descendants
        expect(descendants).to include(child1, child2, grandchild)
      end

      it 'returns an ActiveRecord relation' do
        expect(comment.descendants).to be_a(ActiveRecord::Relation)
      end
    end


    describe '#root_commentable' do
      let(:root_comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }
      let(:nested_comment) { create(:comment, commentable: root_comment, organization: organization, creator: person) }
      let(:deeply_nested_comment) { create(:comment, commentable: nested_comment, organization: organization, creator: person) }

      it 'returns the original commentable for root comments' do
        expect(root_comment.root_commentable).to eq(assignment)
      end

      it 'traverses up to find root commentable for nested comments' do
        expect(nested_comment.root_commentable).to eq(assignment)
        expect(deeply_nested_comment.root_commentable).to eq(assignment)
      end

      it 'works with different commentable types' do
        ability_comment = create(:comment, :on_ability, organization: organization, creator: person, commentable: ability)
        nested_ability_comment = create(:comment, commentable: ability_comment, organization: organization, creator: person)
        
        expect(nested_ability_comment.root_commentable).to eq(ability)
      end
    end
  end

  describe 'polymorphic associations' do
    it 'can belong to an Assignment' do
      assignment_comment = create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment)
      expect(assignment_comment.commentable).to eq(assignment)
    end

    it 'can belong to an Ability' do
      ability_comment = create(:comment, :on_ability, organization: organization, creator: person, commentable: ability)
      expect(ability_comment.commentable).to eq(ability)
    end

    it 'can belong to an Aspiration' do
      aspiration_comment = create(:comment, :on_aspiration, organization: organization, creator: person, commentable: aspiration)
      expect(aspiration_comment.commentable).to eq(aspiration)
    end

    it 'can belong to another Comment (nested)' do
      parent_comment = create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment)
      nested_comment = create(:comment, commentable: parent_comment, organization: organization, creator: person)
      expect(nested_comment.commentable).to eq(parent_comment)
    end
  end
end
