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
end

