require 'rails_helper'

RSpec.describe TeammateIdentity, type: :model do
  describe 'associations' do
    it { should belong_to(:teammate) }
  end

  describe 'validations' do
    it { should validate_presence_of(:provider) }
    it { should validate_presence_of(:uid) }
    
    describe 'uid uniqueness scoped to provider' do
      let(:teammate) { create(:teammate) }
      let!(:existing_identity) { create(:teammate_identity, teammate: teammate, provider: 'slack', uid: 'U1234567890') }
      
      it 'validates uniqueness of uid scoped to provider' do
        duplicate_identity = build(:teammate_identity, teammate: teammate, provider: 'slack', uid: 'U1234567890')
        expect(duplicate_identity).not_to be_valid
        expect(duplicate_identity.errors[:uid]).to include('has already been taken')
      end
      
      it 'allows same uid with different provider' do
        different_provider_identity = build(:teammate_identity, teammate: teammate, provider: 'jira', uid: 'U1234567890')
        expect(different_provider_identity).to be_valid
      end
    end
    
    describe 'email format validation' do
      it 'allows valid email addresses' do
        identity = build(:teammate_identity, email: 'test@example.com')
        expect(identity).to be_valid
      end
      
      it 'allows blank email' do
        identity = build(:teammate_identity, email: '')
        expect(identity).to be_valid
      end
      
      it 'allows nil email' do
        identity = build(:teammate_identity, email: nil)
        expect(identity).to be_valid
      end
      
      it 'rejects invalid email format' do
        identity = build(:teammate_identity, email: 'invalid-email')
        expect(identity).not_to be_valid
        expect(identity.errors[:email]).to include('is invalid')
      end
    end
  end

  describe 'scopes' do
    let!(:slack_identity) { create(:teammate_identity, :slack) }
    let!(:jira_identity) { create(:teammate_identity, :jira) }
    let!(:linear_identity) { create(:teammate_identity, :linear) }
    let!(:asana_identity) { create(:teammate_identity, :asana) }

    describe '.slack' do
      it 'returns only Slack identities' do
        expect(TeammateIdentity.slack).to contain_exactly(slack_identity)
      end
    end

    describe '.jira' do
      it 'returns only Jira identities' do
        expect(TeammateIdentity.jira).to contain_exactly(jira_identity)
      end
    end

    describe '.linear' do
      it 'returns only Linear identities' do
        expect(TeammateIdentity.linear).to contain_exactly(linear_identity)
      end
    end

    describe '.asana' do
      it 'returns only Asana identities' do
        expect(TeammateIdentity.asana).to contain_exactly(asana_identity)
      end
    end
  end

  describe 'instance methods' do
    let(:slack_identity) { build(:teammate_identity, :slack) }
    let(:jira_identity) { build(:teammate_identity, :jira) }
    let(:linear_identity) { build(:teammate_identity, :linear) }
    let(:asana_identity) { build(:teammate_identity, :asana) }

    describe 'provider check methods' do
      it 'correctly identifies Slack provider' do
        expect(slack_identity.slack?).to be true
        expect(slack_identity.jira?).to be false
        expect(slack_identity.linear?).to be false
        expect(slack_identity.asana?).to be false
      end

      it 'correctly identifies Jira provider' do
        expect(jira_identity.jira?).to be true
        expect(jira_identity.slack?).to be false
        expect(jira_identity.linear?).to be false
        expect(jira_identity.asana?).to be false
      end

      it 'correctly identifies Linear provider' do
        expect(linear_identity.linear?).to be true
        expect(linear_identity.slack?).to be false
        expect(linear_identity.jira?).to be false
        expect(linear_identity.asana?).to be false
      end

      it 'correctly identifies Asana provider' do
        expect(asana_identity.asana?).to be true
        expect(asana_identity.slack?).to be false
        expect(asana_identity.jira?).to be false
        expect(asana_identity.linear?).to be false
      end
    end

    describe '#display_name' do
      it 'returns formatted display name with name and email' do
        identity = build(:teammate_identity, provider: 'slack', name: 'John Doe', email: 'john@example.com')
        expect(identity.display_name).to eq('Slack (John Doe - john@example.com)')
      end

      it 'returns formatted display name with only email when name is blank' do
        identity = build(:teammate_identity, provider: 'slack', name: '', email: 'john@example.com')
        expect(identity.display_name).to eq('Slack (john@example.com)')
      end

      it 'returns formatted display name with only email when name is nil' do
        identity = build(:teammate_identity, provider: 'slack', name: nil, email: 'john@example.com')
        expect(identity.display_name).to eq('Slack (john@example.com)')
      end
    end

    describe '#first_name and #last_name' do
      it 'extracts first name correctly' do
        identity = build(:teammate_identity, name: 'John Doe')
        expect(identity.first_name).to eq('John')
        expect(identity.last_name).to eq('Doe')
      end

      it 'handles single name' do
        identity = build(:teammate_identity, name: 'John')
        expect(identity.first_name).to eq('John')
        expect(identity.last_name).to eq('John')
      end

      it 'handles multiple names' do
        identity = build(:teammate_identity, name: 'John Michael Doe')
        expect(identity.first_name).to eq('John')
        expect(identity.last_name).to eq('Doe')
      end

      it 'returns nil for blank name' do
        identity = build(:teammate_identity, name: '')
        expect(identity.first_name).to be_nil
        expect(identity.last_name).to be_nil
      end
    end

    describe '#has_profile_image?' do
      it 'returns true when profile_image_url is present' do
        identity = build(:teammate_identity, profile_image_url: 'https://example.com/avatar.jpg')
        expect(identity.has_profile_image?).to be true
      end

      it 'returns false when profile_image_url is blank' do
        identity = build(:teammate_identity, profile_image_url: '')
        expect(identity.has_profile_image?).to be false
      end

      it 'returns false when profile_image_url is nil' do
        identity = build(:teammate_identity, profile_image_url: nil)
        expect(identity.has_profile_image?).to be false
      end
    end

    describe 'raw data accessors' do
      let(:identity) do
        build(:teammate_identity, raw_data: {
          'info' => { 'name' => 'Test User', 'email' => 'test@example.com' },
          'credentials' => { 'token' => 'test_token' },
          'extra' => { 'raw_info' => { 'id' => '123' } }
        })
      end

      describe '#raw_info' do
        it 'returns info section from raw_data' do
          expect(identity.raw_info).to eq({ 'name' => 'Test User', 'email' => 'test@example.com' })
        end
      end

      describe '#raw_credentials' do
        it 'returns credentials section from raw_data' do
          expect(identity.raw_credentials).to eq({ 'token' => 'test_token' })
        end
      end

      describe '#raw_extra' do
        it 'returns extra section from raw_data' do
          expect(identity.raw_extra).to eq({ 'raw_info' => { 'id' => '123' } })
        end
      end

      it 'returns empty hash when raw_data is nil' do
        identity = build(:teammate_identity, raw_data: nil)
        expect(identity.raw_info).to eq({})
        expect(identity.raw_credentials).to eq({})
        expect(identity.raw_extra).to eq({})
      end
    end
  end

  describe 'class methods' do
    let(:organization) { create(:organization) }
    let(:person) { create(:person) }
    let(:teammate) { create(:teammate, person: person, organization: organization) }
    let!(:slack_identity) { create(:teammate_identity, :slack, teammate: teammate, uid: 'U1234567890') }

    describe '.find_teammate_by_slack_id' do
      it 'finds teammate by Slack user ID in specific organization' do
        found_teammate = TeammateIdentity.find_teammate_by_slack_id('U1234567890', organization)
        expect(found_teammate).to be_a(Teammate)
        expect(found_teammate.id).to eq(teammate.id)
      end

      it 'returns nil when Slack user ID not found' do
        found_teammate = TeammateIdentity.find_teammate_by_slack_id('U9999999999', organization)
        expect(found_teammate).to be_nil
      end

      it 'returns nil when organization does not match' do
        other_organization = create(:organization)
        found_teammate = TeammateIdentity.find_teammate_by_slack_id('U1234567890', other_organization)
        expect(found_teammate).to be_nil
      end
    end

    describe '.find_teammate_by_provider_id' do
      let!(:jira_identity) { create(:teammate_identity, :jira, teammate: teammate, uid: 'jira_user_123') }

      it 'finds teammate by provider and UID in specific organization' do
        found_teammate = TeammateIdentity.find_teammate_by_provider_id('jira', 'jira_user_123', organization)
        expect(found_teammate).to be_a(Teammate)
        expect(found_teammate.id).to eq(teammate.id)
      end

      it 'finds teammate by Slack provider' do
        found_teammate = TeammateIdentity.find_teammate_by_provider_id('slack', 'U1234567890', organization)
        expect(found_teammate).to be_a(Teammate)
        expect(found_teammate.id).to eq(teammate.id)
      end

      it 'returns nil when provider/UID combination not found' do
        found_teammate = TeammateIdentity.find_teammate_by_provider_id('linear', 'linear_user_999', organization)
        expect(found_teammate).to be_nil
      end

      it 'returns nil when organization does not match' do
        other_organization = create(:organization)
        found_teammate = TeammateIdentity.find_teammate_by_provider_id('slack', 'U1234567890', other_organization)
        expect(found_teammate).to be_nil
      end
    end
  end
end
