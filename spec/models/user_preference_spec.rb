require 'rails_helper'

RSpec.describe UserPreference, type: :model do
  let(:person) { create(:person) }
  
  describe 'associations' do
    it { should belong_to(:person) }
  end
  
  describe 'default preferences' do
    let(:preference) { UserPreference.for_person(person) }
    
    it 'sets default preferences' do
      expect(preference.preference(:vertical_nav_open)).to eq(false)
      expect(preference.preference(:vertical_nav_locked)).to eq(false)
      expect(preference.preference(:vertical_nav_mode)).to eq('closed_unless_opened')
    end
    
    it 'provides convenience methods' do
      expect(preference.vertical_nav_open?).to eq(false)
      expect(preference.vertical_nav_locked?).to eq(false)
      expect(preference.vertical_nav_mode).to eq('closed_unless_opened')
    end
  end
  
  describe '.for_person' do
    it 'creates preferences if they do not exist' do
      expect {
        UserPreference.for_person(person)
      }.to change { UserPreference.count }.by(1)
    end
    
    it 'returns existing preferences if they exist' do
      existing = UserPreference.create!(person: person, preferences: { vertical_nav_open: false })
      
      expect(UserPreference.for_person(person)).to eq(existing)
    end
  end
  
  describe '#update_preference' do
    let(:preference) { UserPreference.for_person(person) }
    
    it 'updates a preference value' do
      preference.update_preference(:vertical_nav_open, true)
      
      expect(preference.reload.preference(:vertical_nav_open)).to eq(true)
    end
    
    it 'saves the changes' do
      expect {
        preference.update_preference(:vertical_nav_locked, true)
      }.to change { preference.reload.preference(:vertical_nav_locked) }.from(false).to(true)
    end
  end
  
  describe '#preference' do
    let(:preference) { UserPreference.create!(person: person, preferences: { vertical_nav_locked: true }) }
    
    it 'returns the preference value' do
      expect(preference.preference(:vertical_nav_locked)).to eq(true)
    end
    
    it 'returns default if preference is not set' do
      expect(preference.preference(:vertical_nav_open)).to eq(false)
    end
  end
  
  describe 'validations' do
    it 'ensures preferences is always a hash with defaults' do
      preference = UserPreference.new(person: person, preferences: nil)
      preference.valid?
      
      expect(preference.preferences).to be_a(Hash)
      expect(preference.preferences).to include('vertical_nav_open', 'vertical_nav_locked', 'vertical_nav_mode')
      expect(preference.preferences).not_to include('layout')
    end
  end

  describe 'digest preferences' do
    let(:preference) { UserPreference.for_person(person) }

    it 'includes digest keys in defaults (off for all three mediums)' do
      expect(preference.preference(:digest_slack)).to eq('off')
      expect(preference.preference(:digest_email)).to eq('off')
      expect(preference.preference(:digest_sms)).to eq('off')
    end

    it 'updates digest preferences' do
      preference.update_preference('digest_slack', 'on')
      preference.update_preference('digest_email', 'on')
      preference.update_preference('digest_sms', 'off')

      expect(preference.reload.preference(:digest_slack)).to eq('on')
      expect(preference.preference(:digest_email)).to eq('on')
      expect(preference.preference(:digest_sms)).to eq('off')
    end

    describe '#effective_digest_slack' do
      let(:organization) { create(:organization) }
      let(:teammate) { create(:company_teammate, person: person, organization: organization) }

      it 'returns off when no preference set' do
        create(:teammate_identity, :slack, teammate: teammate)
        expect(preference.effective_digest_slack(teammate)).to eq('off')
      end

      it 'returns off when teammate has no Slack identity and no preference set' do
        expect(preference.effective_digest_slack(teammate)).to eq('off')
      end

      it 'returns stored value when set' do
        preference.update_preference('digest_slack', 'on')
        create(:teammate_identity, :slack, teammate: teammate)
        expect(preference.effective_digest_slack(teammate)).to eq('on')
      end
    end

    describe '#effective_digest_email' do
      it 'returns off when not set' do
        expect(preference.effective_digest_email).to eq('off')
      end

      it 'returns stored value when set' do
        preference.update_preference('digest_email', 'on')
        expect(preference.effective_digest_email).to eq('on')
      end
    end

    describe '#effective_digest_sms' do
      it 'returns off when no preference set' do
        person.update!(unique_textable_phone_number: '+15551234567')
        expect(preference.effective_digest_sms(person)).to eq('off')
      end

      it 'returns off when person has no phone and no preference set' do
        person.update!(unique_textable_phone_number: nil)
        expect(preference.effective_digest_sms(person)).to eq('off')
      end

      it 'returns stored value when set' do
        preference.update_preference('digest_sms', 'on')
        person.update!(unique_textable_phone_number: '+15551234567')
        expect(preference.effective_digest_sms(person)).to eq('on')
      end

      it 'treats legacy daily or weekly settings as enabled' do
        preference.update_preference('digest_sms', 'daily')
        expect(preference.effective_digest_sms(person)).to eq('on')
      end
    end
  end
end

