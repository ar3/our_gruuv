require 'rails_helper'

RSpec.describe Comments::ResolveService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:root_comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }
  let!(:child_comment) { create(:comment, commentable: root_comment, organization: organization, creator: person) }

  describe '#call' do
    it 'resolves the comment' do
      result = described_class.call(comment: root_comment)
      
      expect(result).to be_ok
      expect(root_comment.reload.resolved_at).not_to be_nil
    end

    it 'cascades resolution to descendants' do
      described_class.call(comment: root_comment)
      
      expect(child_comment.reload.resolved_at).not_to be_nil
    end

    it 'triggers Slack notification for root comments' do
      expect(Comments::PostNotificationJob).to receive(:perform_and_get_result).with(root_comment.id)
      
      described_class.call(comment: root_comment)
    end
  end
end
