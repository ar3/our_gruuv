require 'rails_helper'

RSpec.describe Comments::UnresolveService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:resolved_comment) { create(:comment, :resolved, :on_assignment, organization: organization, creator: person, commentable: assignment) }
  let!(:child_comment) { create(:comment, :resolved, commentable: resolved_comment, organization: organization, creator: person) }

  describe '#call' do
    it 'unresolves the comment' do
      result = described_class.call(comment: resolved_comment)
      
      expect(result).to be_ok
      expect(resolved_comment.reload.resolved_at).to be_nil
    end

    it 'does not affect descendants (independent behavior)' do
      described_class.call(comment: resolved_comment)
      
      expect(child_comment.reload.resolved_at).not_to be_nil
    end

    it 'triggers Slack notification for root comments' do
      expect(Comments::PostNotificationJob).to receive(:perform_and_get_result).with(resolved_comment.id)
      
      described_class.call(comment: resolved_comment)
    end
  end
end
