require 'rails_helper'

RSpec.describe SlackProfileMatcherService do
  let(:organization) { create(:organization, :company) }
  let(:slack_config) { create(:slack_configuration, organization: organization) }
  let(:service) { described_class.new }
  let(:mock_slack_service) { instance_double(SlackService) }

  before do
    slack_config
    allow(SlackService).to receive(:new).with(organization).and_return(mock_slack_service)
  end

  describe '#call' do
    context 'when organization is missing' do
      it 'returns error hash' do
        result = service.call(nil)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Organization is missing')
      end
    end

    context 'when Slack is not configured' do
      before do
        allow(organization).to receive(:calculated_slack_config).and_return(nil)
      end

      it 'returns error hash' do
        result = service.call(organization)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Slack not configured for this organization')
      end
    end

    context 'when Slack users cannot be fetched' do
      before do
        allow(mock_slack_service).to receive(:list_users).and_return([])
      end

      it 'returns error hash' do
        result = service.call(organization)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Failed to fetch Slack users')
      end
    end

    context 'when matching teammates' do
      let(:person1) { create(:person, email: 'john@example.com') }
      let(:person2) { create(:person, email: 'jane@example.com') }
      let(:person3) { create(:person, email: 'nomatch@example.com') }
      let!(:teammate1) { create(:teammate, person: person1, organization: organization, last_terminated_at: nil) }
      let!(:teammate2) { create(:teammate, person: person2, organization: organization, last_terminated_at: nil) }
      let!(:teammate3) { create(:teammate, person: person3, organization: organization, last_terminated_at: nil) }
      let!(:terminated_teammate) { create(:teammate, person: create(:person, email: 'terminated@example.com'), organization: organization, first_employed_at: 2.days.ago, last_terminated_at: 1.day.ago) }

      let(:slack_users) do
        [
          {
            'id' => 'U123456',
            'name' => 'john',
            'profile' => {
              'email' => 'john@example.com',
              'real_name' => 'John Doe',
              'image_512' => 'https://slack.com/avatar/john.jpg'
            }
          },
          {
            'id' => 'U789012',
            'name' => 'jane',
            'profile' => {
              'email' => 'jane@example.com',
              'real_name' => 'Jane Smith',
              'image_192' => 'https://slack.com/avatar/jane.jpg'
            }
          },
          {
            'id' => 'U345678',
            'name' => 'other',
            'profile' => {
              'email' => 'other@example.com',
              'real_name' => 'Other User'
            }
          }
        ]
      end

      before do
        allow(mock_slack_service).to receive(:list_users).and_return(slack_users)
      end

      it 'matches teammates by email and creates identities' do
        result = service.call(organization)

        expect(result[:success]).to be true
        expect(result[:matched_count]).to eq(2)
        expect(result[:total_teammates]).to eq(3)

        # Verify identities were created
        expect(teammate1.reload.slack_identity).to be_present
        expect(teammate1.slack_identity.uid).to eq('U123456')
        expect(teammate1.slack_identity.email).to eq('john@example.com')
        expect(teammate1.slack_identity.name).to eq('John Doe')
        expect(teammate1.slack_identity.profile_image_url).to eq('https://slack.com/avatar/john.jpg')

        expect(teammate2.reload.slack_identity).to be_present
        expect(teammate2.slack_identity.uid).to eq('U789012')
        expect(teammate2.slack_identity.email).to eq('jane@example.com')
        expect(teammate2.slack_identity.name).to eq('Jane Smith')
        expect(teammate2.slack_identity.profile_image_url).to eq('https://slack.com/avatar/jane.jpg')

        # Verify unmatched teammate has no identity
        expect(teammate3.reload.slack_identity).to be_nil
      end

      it 'does not update existing identities' do
        existing_identity = create(:teammate_identity, :slack, teammate: teammate1, uid: 'U123456', name: 'Old Name', profile_image_url: 'https://old-avatar.jpg')

        result = service.call(organization)

        expect(result[:success]).to be true
        expect(result[:matched_count]).to eq(1) # Only teammate2 should be matched (teammate1 already has identity)
        expect(existing_identity.reload.name).to eq('Old Name') # Should remain unchanged
        expect(existing_identity.profile_image_url).to eq('https://old-avatar.jpg') # Should remain unchanged
      end
      
      it 'skips teammates that already have Slack identity' do
        create(:teammate_identity, :slack, teammate: teammate1, uid: 'U999999', name: 'Existing Identity')

        result = service.call(organization)

        expect(result[:success]).to be true
        expect(result[:matched_count]).to eq(1) # Only teammate2 should be matched
        expect(teammate1.reload.slack_identity.uid).to eq('U999999') # Should remain unchanged
      end

      it 'handles case-insensitive email matching' do
        person1.update!(email: 'JOHN@EXAMPLE.COM')
        slack_users.first['profile']['email'] = 'john@example.com'

        result = service.call(organization)

        expect(result[:success]).to be true
        expect(result[:matched_count]).to eq(2)
        expect(teammate1.reload.slack_identity).to be_present
      end

      it 'only processes active teammates' do
        result = service.call(organization)

        expect(result[:total_teammates]).to eq(3)
        expect(terminated_teammate.reload.slack_identity).to be_nil
      end

      it 'handles missing profile image gracefully' do
        slack_users.first['profile'].delete('image_512')
        slack_users.first['profile'].delete('image_192')

        result = service.call(organization)

        expect(result[:success]).to be true
        expect(teammate1.reload.slack_identity.profile_image_url).to be_nil
      end
    end

    context 'when errors occur during processing' do
      let(:person) { create(:person, email: 'test@example.com') }
      let!(:teammate) { create(:teammate, person: person, organization: organization) }

      let(:slack_users) do
        [
          {
            'id' => 'U123456',
            'profile' => {
              'email' => 'test@example.com',
              'real_name' => 'Test User'
            }
          }
        ]
      end

      before do
        allow(mock_slack_service).to receive(:list_users).and_return(slack_users)
        allow_any_instance_of(TeammateIdentity).to receive(:save).and_raise(ActiveRecord::RecordInvalid.new(TeammateIdentity.new))
      end

      it 'continues processing and reports errors' do
        result = service.call(organization)

        expect(result[:success]).to be true
        expect(result[:matched_count]).to eq(0)
        expect(result[:errors]).to be_present
      end
    end
  end
end


