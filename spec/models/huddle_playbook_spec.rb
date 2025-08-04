require 'rails_helper'

RSpec.describe HuddlePlaybook, type: :model do
  let(:organization) { create(:organization) }
  let(:huddle_playbook) { build(:huddle_playbook, organization: organization) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(huddle_playbook).to be_valid
    end

    it 'allows blank special_session_name' do
      huddle_playbook.special_session_name = nil
      expect(huddle_playbook).to be_valid
    end

    it 'normalizes empty string special_session_name to empty string' do
      huddle_playbook.special_session_name = ''
      huddle_playbook.valid?
      expect(huddle_playbook.special_session_name).to eq('')
    end

    it 'normalizes nil special_session_name to empty string' do
      huddle_playbook.special_session_name = nil
      huddle_playbook.valid?
      expect(huddle_playbook.special_session_name).to eq('')
    end

    it 'normalizes whitespace-only special_session_name to empty string' do
      huddle_playbook.special_session_name = '   '
      huddle_playbook.valid?
      expect(huddle_playbook.special_session_name).to eq('')
    end

    it 'requires unique special_session_name per organization' do
      create(:huddle_playbook, organization: organization, special_session_name: 'Sprint Planning')
      duplicate = build(:huddle_playbook, organization: organization, special_session_name: 'Sprint Planning')
      
      # Should fail due to database constraint, not Rails validation
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'treats nil and empty string as the same for uniqueness' do
      create(:huddle_playbook, organization: organization, special_session_name: '')
      duplicate = build(:huddle_playbook, organization: organization, special_session_name: nil)
      duplicate.valid? # Trigger normalization
      
      # Should fail due to database constraint, not Rails validation
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows same special_session_name for different organizations' do
      other_organization = create(:organization)
      create(:huddle_playbook, organization: organization, special_session_name: 'Sprint Planning')
      duplicate = build(:huddle_playbook, organization: other_organization, special_session_name: 'Sprint Planning')
      expect(duplicate).to be_valid
    end

    it 'validates slack_channel format' do
      huddle_playbook.slack_channel = 'invalid-channel'
      expect(huddle_playbook).not_to be_valid
      expect(huddle_playbook.errors[:slack_channel]).to include('must be a valid Slack channel (e.g., #general)')
    end

    it 'accepts valid slack_channel format' do
      huddle_playbook.slack_channel = '#team-huddles'
      expect(huddle_playbook).to be_valid
    end

    it 'allows blank slack_channel' do
      huddle_playbook.slack_channel = ''
      expect(huddle_playbook).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to an organization' do
      expect(huddle_playbook).to belong_to(:organization)
    end

    it 'has many huddles' do
      expect(huddle_playbook).to have_many(:huddles)
    end
  end

  describe '#display_name' do
    it 'returns titleized special_session_name when present' do
      huddle_playbook.special_session_name = 'sprint planning'
      expect(huddle_playbook.display_name).to eq('Sprint Planning')
    end

    it 'returns default name when special_session_name is blank' do
      huddle_playbook.special_session_name = ''
      expect(huddle_playbook.display_name).to eq('Base Team Playbook')
    end
  end

  describe '#slack_channel_or_organization_default' do
    let(:slack_config) { instance_double('SlackConfiguration', default_channel_or_general: '#bot-test') }

    before do
      allow(organization).to receive(:slack_configuration).and_return(slack_config)
    end

    it 'returns slack_channel when present' do
      huddle_playbook.slack_channel = '#team-huddles'
      expect(huddle_playbook.slack_channel_or_organization_default).to eq('#team-huddles')
    end

    it 'returns organization default when slack_channel is blank' do
      huddle_playbook.slack_channel = ''
      expect(huddle_playbook.slack_channel_or_organization_default).to eq('#bot-test')
    end

    it 'returns #bot-test when organization has no slack configuration' do
      huddle_playbook.slack_channel = ''
      allow(organization).to receive(:slack_configuration).and_return(nil)
      expect(huddle_playbook.slack_channel_or_organization_default).to eq('#bot-test')
    end
  end
end
