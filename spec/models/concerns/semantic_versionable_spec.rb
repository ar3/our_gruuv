require 'rails_helper'

RSpec.describe SemanticVersionable, type: :model do
  # Use Aspiration model which includes the concern
  let(:organization) { create(:organization) }
  let(:aspiration) { create(:aspiration, organization: organization, semantic_version: '1.2.3') }

  describe '#next_major_version' do
    it 'increments major version and resets minor and patch' do
      expect(aspiration.next_major_version).to eq('2.0.0')
    end
  end

  describe '#next_minor_version' do
    it 'increments minor version and resets patch' do
      expect(aspiration.next_minor_version).to eq('1.3.0')
    end
  end

  describe '#next_patch_version' do
    it 'increments patch version' do
      expect(aspiration.next_patch_version).to eq('1.2.4')
    end
  end

  describe 'validations' do
    it 'validates semantic_version format' do
      aspiration.semantic_version = 'invalid'
      expect(aspiration).not_to be_valid
      expect(aspiration.errors[:semantic_version]).to be_present
    end

    it 'accepts valid semantic version format' do
      aspiration.semantic_version = '1.2.3'
      expect(aspiration).to be_valid
    end
  end
end

