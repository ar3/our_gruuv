require 'rails_helper'

RSpec.describe OneOnOneLink, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }

  describe 'associations' do
    it { should belong_to(:teammate) }
  end

  describe 'validations' do
    it 'validates URL format when present' do
      link = build(:one_on_one_link, teammate: teammate, url: 'invalid-url')
      expect(link).not_to be_valid
      expect(link.errors[:url]).to be_present
    end

    it 'accepts valid HTTP URLs' do
      link = build(:one_on_one_link, teammate: teammate, url: 'http://example.com')
      expect(link).to be_valid
    end

    it 'accepts valid HTTPS URLs' do
      link = build(:one_on_one_link, teammate: teammate, url: 'https://example.com')
      expect(link).to be_valid
    end

    it 'allows blank URL' do
      link = build(:one_on_one_link, teammate: teammate, url: nil)
      expect(link).to be_valid
    end

    it 'validates uniqueness of teammate_id' do
      create(:one_on_one_link, teammate: teammate)
      duplicate_link = build(:one_on_one_link, teammate: teammate)
      expect(duplicate_link).not_to be_valid
      expect(duplicate_link.errors[:teammate_id]).to be_present
    end

    it 'allows multiple links for different teammates' do
      other_teammate = create(:teammate, person: create(:person), organization: organization)
      create(:one_on_one_link, teammate: teammate)
      other_link = build(:one_on_one_link, teammate: other_teammate)
      expect(other_link).to be_valid
    end
  end

  describe '#has_deep_integration?' do
    it 'returns false when deep_integration_config is empty' do
      link = create(:one_on_one_link, teammate: teammate, deep_integration_config: {})
      expect(link.has_deep_integration?).to be false
    end

    it 'returns false when deep_integration_config is nil' do
      link = create(:one_on_one_link, teammate: teammate, deep_integration_config: nil)
      expect(link.has_deep_integration?).to be false
    end

    it 'returns true when deep_integration_config has data' do
      link = create(:one_on_one_link, teammate: teammate, deep_integration_config: { 'asana_project_id' => '123' })
      expect(link.has_deep_integration?).to be true
    end
  end

  describe '#asana_project_id' do
    it 'returns nil when no asana_project_id in config' do
      link = create(:one_on_one_link, teammate: teammate, deep_integration_config: {})
      expect(link.asana_project_id).to be_nil
    end

    it 'returns the asana_project_id from config' do
      link = create(:one_on_one_link, teammate: teammate, deep_integration_config: { 'asana_project_id' => '123456' })
      expect(link.asana_project_id).to eq('123456')
    end
  end

  describe '#is_asana_link?' do
    it 'returns false when URL is blank' do
      link = create(:one_on_one_link, teammate: teammate, url: nil)
      expect(link.is_asana_link?).to be false
    end

    it 'returns false for non-Asana URLs' do
      link = create(:one_on_one_link, teammate: teammate, url: 'https://example.com')
      expect(link.is_asana_link?).to be false
    end

    it 'returns true for app.asana.com URLs' do
      link = create(:one_on_one_link, teammate: teammate, url: 'https://app.asana.com/0/123456/789')
      expect(link.is_asana_link?).to be true
    end

    it 'returns true for asana.com URLs' do
      link = create(:one_on_one_link, teammate: teammate, url: 'https://asana.com/projects/123')
      expect(link.is_asana_link?).to be true
    end
  end
end

