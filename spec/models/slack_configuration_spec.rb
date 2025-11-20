require 'rails_helper'

RSpec.describe SlackConfiguration, type: :model do
  let(:organization) { create(:organization, type: 'Company') }
  
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:created_by).optional }
  end
  
  describe 'validations' do
    subject { build(:slack_configuration, organization: organization) }
    
    it { should validate_presence_of(:workspace_id) }
    it { should validate_presence_of(:workspace_name) }
    it { should validate_presence_of(:bot_token) }
    it { should validate_presence_of(:installed_at) }
    it { should validate_uniqueness_of(:workspace_id) }
    it { should validate_uniqueness_of(:bot_token) }
  end
  
  describe 'scopes' do
    let!(:active_config) { create(:slack_configuration, organization: organization) }
    
    it 'returns only active configurations' do
      expect(SlackConfiguration.active).to include(active_config)
    end
  end
  
  describe 'instance methods' do
    let(:slack_config) { create(:slack_configuration, organization: organization) }
    
    describe '#configured?' do
      it 'returns true when bot_token and workspace_id are present' do
        expect(slack_config.configured?).to be true
      end
      
      it 'returns false when bot_token is missing' do
        slack_config.bot_token = nil
        expect(slack_config.configured?).to be false
      end
      
      it 'returns false when workspace_id is missing' do
        slack_config.workspace_id = nil
        expect(slack_config.configured?).to be false
      end
    end
    
    describe '#workspace_url' do
      it 'returns the correct Slack workspace URL' do
        expect(slack_config.workspace_url).to eq("https://#{slack_config.workspace_subdomain}.slack.com")
      end
    end
    
    describe '#display_name' do
      it 'returns workspace name and ID' do
        expect(slack_config.display_name).to eq("#{slack_config.workspace_name} (#{slack_config.workspace_id})")
      end
    end
    
    describe '#configured_by_name' do
      context 'when created_by is present' do
        let(:creator) { create(:person, first_name: 'John', last_name: 'Doe') }
        let(:slack_config_with_creator) { create(:slack_configuration, organization: organization, created_by: creator) }
        
        it 'returns the creator\'s display name' do
          expect(slack_config_with_creator.configured_by_name).to eq('John Doe')
        end
      end
      
      context 'when created_by is nil' do
        it 'returns "Unknown"' do
          expect(slack_config.configured_by_name).to eq('Unknown')
        end
      end
    end
  end
  
  # TODO: Add encryption tests when Active Record encryption is configured
  # describe 'encryption' do
  #   it 'encrypts the bot_token' do
  #     slack_config = create(:slack_configuration, organization: organization)
  #     expect(slack_config.bot_token).to be_present
  #     expect(slack_config.encrypted_bot_token).to be_present
  #     expect(slack_config.encrypted_bot_token).not_to eq(slack_config.bot_token)
  #   end
  # end
end
