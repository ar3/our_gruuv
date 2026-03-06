require 'rails_helper'

RSpec.describe UserPreference, type: :model do
  let(:person) { create(:person) }
  
  describe 'associations' do
    it { should belong_to(:person) }
  end
  
  describe 'default preferences' do
    let(:preference) { UserPreference.for_person(person) }
    
    it 'sets default preferences' do
      expect(preference.preference(:layout)).to eq('vertical')
      expect(preference.preference(:vertical_nav_open)).to eq(false)
      expect(preference.preference(:vertical_nav_locked)).to eq(false)
    end
    
    it 'provides convenience methods' do
      expect(preference.layout).to eq('vertical')
      expect(preference.vertical_nav_open?).to eq(false)
      expect(preference.vertical_nav_locked?).to eq(false)
    end
  end
  
  describe '.for_person' do
    it 'creates preferences if they do not exist' do
      expect {
        UserPreference.for_person(person)
      }.to change { UserPreference.count }.by(1)
    end
    
    it 'returns existing preferences if they exist' do
      existing = UserPreference.create!(person: person, preferences: { layout: 'vertical' })
      
      expect(UserPreference.for_person(person)).to eq(existing)
    end
  end
  
  describe '#update_preference' do
    let(:preference) { UserPreference.for_person(person) }
    
    it 'updates a preference value' do
      preference.update_preference(:layout, 'vertical')
      
      expect(preference.reload.preference(:layout)).to eq('vertical')
    end
    
    it 'saves the changes' do
      expect {
        preference.update_preference(:layout, 'horizontal')
      }.to change { preference.reload.preference(:layout) }.from('vertical').to('horizontal')
    end
  end
  
  describe '#preference' do
    let(:preference) { UserPreference.create!(person: person, preferences: { layout: 'vertical' }) }
    
    it 'returns the preference value' do
      expect(preference.preference(:layout)).to eq('vertical')
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
      expect(preference.preferences).to include('layout', 'vertical_nav_open', 'vertical_nav_locked')
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
      preference.update_preference('digest_slack', 'weekly')
      preference.update_preference('digest_email', 'daily')
      preference.update_preference('digest_sms', 'off')

      expect(preference.reload.preference(:digest_slack)).to eq('weekly')
      expect(preference.preference(:digest_email)).to eq('daily')
      expect(preference.preference(:digest_sms)).to eq('off')
    end

    describe '#effective_digest_slack' do
      let(:organization) { create(:organization) }
      let(:teammate) { create(:company_teammate, person: person, organization: organization) }

      it 'returns off when no preference set (opt-in; scheduled digests only for explicit daily/weekly)' do
        create(:teammate_identity, :slack, teammate: teammate)
        expect(preference.effective_digest_slack(teammate)).to eq('off')
      end

      it 'returns off when teammate has no Slack identity and no preference set' do
        expect(preference.effective_digest_slack(teammate)).to eq('off')
      end

      it 'returns stored value when set' do
        preference.update_preference('digest_slack', 'daily')
        create(:teammate_identity, :slack, teammate: teammate)
        expect(preference.effective_digest_slack(teammate)).to eq('daily')
      end
    end

    describe '#effective_digest_email' do
      it 'returns off when not set' do
        expect(preference.effective_digest_email).to eq('off')
      end

      it 'returns stored value when set' do
        preference.update_preference('digest_email', 'weekly')
        expect(preference.effective_digest_email).to eq('weekly')
      end
    end

    describe '#effective_digest_sms' do
      it 'returns off when no preference set (opt-in; scheduled digests only for explicit daily/weekly)' do
        person.update!(unique_textable_phone_number: '+15551234567')
        expect(preference.effective_digest_sms(person)).to eq('off')
      end

      it 'returns off when person has no phone and no preference set' do
        person.update!(unique_textable_phone_number: nil)
        expect(preference.effective_digest_sms(person)).to eq('off')
      end

      it 'returns stored value when set' do
        preference.update_preference('digest_sms', 'daily')
        person.update!(unique_textable_phone_number: '+15551234567')
        expect(preference.effective_digest_sms(person)).to eq('daily')
      end
    end
  end
end

