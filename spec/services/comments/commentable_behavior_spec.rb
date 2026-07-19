# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comments::CommentableBehavior do
  let(:organization) { create(:organization, :company) }

  describe '.for' do
    it 'returns Maap behavior for assignments' do
      assignment = create(:assignment, company: organization)
      expect(described_class.for(assignment)).to be_a(Comments::CommentableBehaviors::Maap)
    end

    it 'returns Observation behavior for observations' do
      observation = create(:observation, :published, company: organization)
      expect(described_class.for(observation)).to be_a(Comments::CommentableBehaviors::Observation)
    end

    it 'uses the root commentable for nested comments' do
      observation = create(:observation, :published, company: organization)
      root = create(:comment, organization: organization, commentable: observation)
      reply = create(:comment, organization: organization, commentable: root)
      expect(described_class.for(reply)).to be_a(Comments::CommentableBehaviors::Observation)
    end
  end

  describe Comments::CommentableBehaviors::Observation do
    it 'allows comments only when published and not soft-deleted' do
      published = create(:observation, :published, company: organization)
      draft = build(:observation, company: organization, published_at: nil)
      draft.save!(validate: false)

      expect(described_class.new(published).allows_comments?).to be true
      expect(described_class.new(draft).allows_comments?).to be false
      expect(described_class.new(published).allows_resolve?).to be false
      expect(described_class.new(published).slack_channel_notify?).to be false
    end
  end
end
