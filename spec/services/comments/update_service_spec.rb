require 'rails_helper'

RSpec.describe Comments::UpdateService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:root_comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }

  describe '#call' do
    context 'with valid params' do
      it 'updates the comment' do
        result = described_class.call(
          comment: root_comment,
          params: { body: 'Updated comment body' }
        )
        
        expect(result).to be_ok
        expect(root_comment.reload.body).to eq('Updated comment body')
      end

      it 'triggers Slack notification when body changes' do
        expect(Comments::PostNotificationJob).to receive(:perform_and_get_result).with(root_comment.id)
        
        described_class.call(
          comment: root_comment,
          params: { body: 'Updated comment body' }
        )
      end

      it 'triggers Slack notification when resolved_at changes' do
        expect(Comments::PostNotificationJob).to receive(:perform_and_get_result).with(root_comment.id)
        
        described_class.call(
          comment: root_comment,
          params: { resolved_at: Time.current }
        )
      end

      it 'does not trigger Slack notification if neither body nor resolved_at changed' do
        # Update with same body
        expect(Comments::PostNotificationJob).not_to receive(:perform_and_get_result)
        
        described_class.call(
          comment: root_comment,
          params: { body: root_comment.body }
        )
      end
    end

    context 'with invalid params' do
      it 'returns error result' do
        result = described_class.call(
          comment: root_comment,
          params: { body: nil }
        )
        
        expect(result).not_to be_ok
        expect(result.error).to be_present
      end
    end
  end
end
