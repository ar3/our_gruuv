require 'rails_helper'

RSpec.describe Comments::CreateService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:comment) { build(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }

  describe '#call' do
    context 'with root comment' do
      it 'creates the comment' do
        result = described_class.call(
          comment: comment,
          commentable: assignment,
          organization: organization,
          creator: person
        )
        
        expect(result).to be_ok
        expect(result.value).to be_persisted
        expect(result.value.body).to eq(comment.body)
      end

      it 'triggers Slack notification for root comments' do
        expect(Comments::PostNotificationJob).to receive(:perform_and_get_result).with(kind_of(Integer))
        
        described_class.call(
          comment: comment,
          commentable: assignment,
          organization: organization,
          creator: person
        )
      end
    end

    context 'with nested comment' do
      let(:root_comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }
      let(:nested_comment) { build(:comment, commentable: root_comment, organization: organization, creator: person) }

      it 'creates the nested comment' do
        result = described_class.call(
          comment: nested_comment,
          commentable: root_comment,
          organization: organization,
          creator: person
        )
        
        expect(result).to be_ok
        expect(result.value).to be_persisted
      end

      it 'triggers Slack notification for root comment when nested comment is created' do
        expect(Comments::PostNotificationJob).to receive(:perform_and_get_result).with(root_comment.id)
        
        described_class.call(
          comment: nested_comment,
          commentable: root_comment,
          organization: organization,
          creator: person
        )
      end
    end

    context 'with invalid comment' do
      let(:invalid_comment) { build(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment, body: nil) }

      it 'returns error result' do
        result = described_class.call(
          comment: invalid_comment,
          commentable: assignment,
          organization: organization,
          creator: person
        )
        
        expect(result).not_to be_ok
        expect(result.error).to be_present
      end
    end
  end
end
