require 'rails_helper'

RSpec.describe ThirdPartyObjectAssociation, type: :model do
  let(:company) { create(:organization, :company) }
  let(:slack_channel) { create(:third_party_object, :slack_channel, organization: company) }
  let(:slack_group) { create(:third_party_object, :slack_group, organization: company) }

  describe 'associations' do
    it { should belong_to(:third_party_object) }
    it { should belong_to(:associatable) }
  end

  describe 'validations' do
    it { should validate_presence_of(:association_type) }
  end

  describe 'scopes' do
    it 'has huddle_review_notification_channels scope' do
      expect(ThirdPartyObjectAssociation).to respond_to(:huddle_review_notification_channels)
    end

    it 'has slack_groups scope' do
      expect(ThirdPartyObjectAssociation).to respond_to(:slack_groups)
    end

    describe '.slack_groups' do
      let(:channel_association) { create(:third_party_object_association, third_party_object: slack_channel, associatable: company, association_type: 'huddle_review_notification_channel') }
      let(:group_association) { create(:third_party_object_association, third_party_object: slack_group, associatable: company, association_type: 'slack_group') }

      it 'returns only slack_group associations' do
        channel_association
        group_association
        
        expect(ThirdPartyObjectAssociation.slack_groups).to include(group_association)
        expect(ThirdPartyObjectAssociation.slack_groups).not_to include(channel_association)
      end
    end
  end
end

