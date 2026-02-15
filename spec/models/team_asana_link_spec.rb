# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeamAsanaLink, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:team) }
    it { is_expected.to have_one(:external_project_cache).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:team_asana_link) }
    it { is_expected.to validate_uniqueness_of(:team_id).with_message(/already has a team Asana link/) }
    it { is_expected.to allow_value('https://app.asana.com/0/123/456').for(:url) }
    it { is_expected.to allow_value('').for(:url) }
    it { is_expected.not_to allow_value('not-a-url').for(:url) }
  end

  describe '#is_asana_link?' do
    it 'returns true for Asana URLs' do
      link = build(:team_asana_link, url: 'https://app.asana.com/0/123/456')
      expect(link.is_asana_link?).to be true
    end

    it 'returns false for non-Asana URLs' do
      link = build(:team_asana_link, url: 'https://example.com/doc')
      expect(link.is_asana_link?).to be false
    end

    it 'returns false when url is blank' do
      link = build(:team_asana_link, url: '')
      expect(link.is_asana_link?).to be false
    end
  end

  describe '#asana_project_id' do
    it 'returns project ID from deep_integration_config' do
      link = build(:team_asana_link, deep_integration_config: { 'asana_project_id' => '123456' })
      expect(link.asana_project_id).to eq('123456')
    end

    it 'returns nil when not set' do
      link = build(:team_asana_link, deep_integration_config: {})
      expect(link.asana_project_id).to be_nil
    end
  end

  describe '#has_deep_integration?' do
    it 'returns true when deep_integration_config has asana_project_id' do
      link = build(:team_asana_link, deep_integration_config: { 'asana_project_id' => '123' })
      expect(link.has_deep_integration?).to be true
    end

    it 'returns false when deep_integration_config is empty' do
      link = build(:team_asana_link, deep_integration_config: {})
      expect(link.has_deep_integration?).to be false
    end
  end

  describe '#external_project_source' do
    it 'returns "asana" for Asana URLs' do
      link = build(:team_asana_link, url: 'https://app.asana.com/0/1/2')
      expect(link.external_project_source).to eq('asana')
    end

    it 'returns nil for unsupported URLs' do
      link = build(:team_asana_link, url: 'https://example.com')
      expect(link.external_project_source).to be_nil
    end
  end

  describe '#organization' do
    it 'returns the team company' do
      org = create(:organization)
      team = create(:team, company: org)
      link = build(:team_asana_link, team: team)
      expect(link.organization).to eq(org)
    end
  end
end
