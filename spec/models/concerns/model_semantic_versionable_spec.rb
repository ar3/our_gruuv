require 'rails_helper'

RSpec.describe ModelSemanticVersionable, type: :model do
  # Use Aspiration model which includes the concern
  let(:organization) { create(:organization) }
  let(:aspiration) { create(:aspiration, organization: organization, semantic_version: '1.2.3') }

  describe 'PaperTrail integration' do
    it 'enables PaperTrail versioning' do
      expect(aspiration).to respond_to(:versions)
    end

    it 'tracks version history' do
      expect(aspiration.versions.count).to eq(1)
      
      aspiration.update!(name: 'Updated Name')
      expect(aspiration.versions.count).to eq(2)
    end
  end

  describe '#next_major_version' do
    it 'increments major version and resets minor and patch' do
      expect(aspiration.next_major_version).to eq('2.0.0')
    end

    it 'returns 1.0.0 when semantic_version is nil' do
      aspiration.semantic_version = nil
      expect(aspiration.next_major_version).to eq('1.0.0')
    end
  end

  describe '#next_minor_version' do
    it 'increments minor version and resets patch' do
      expect(aspiration.next_minor_version).to eq('1.3.0')
    end

    it 'returns 0.1.0 when semantic_version is nil' do
      aspiration.semantic_version = nil
      expect(aspiration.next_minor_version).to eq('0.1.0')
    end
  end

  describe '#next_patch_version' do
    it 'increments patch version' do
      expect(aspiration.next_patch_version).to eq('1.2.4')
    end

    it 'returns 0.0.1 when semantic_version is nil' do
      aspiration.semantic_version = nil
      expect(aspiration.next_patch_version).to eq('0.0.1')
    end
  end

  describe '#major_version' do
    it 'extracts major version number from semantic_version' do
      expect(aspiration.major_version).to eq(1)
    end

    it 'handles version 0 correctly' do
      aspiration.update!(semantic_version: '0.1.0')
      expect(aspiration.major_version).to eq(0)
    end

    it 'handles multi-digit major versions' do
      aspiration.update!(semantic_version: '10.5.2')
      expect(aspiration.major_version).to eq(10)
    end

    it 'returns 0 when semantic_version is nil' do
      aspiration.semantic_version = nil
      expect(aspiration.major_version).to eq(0)
    end
  end

  describe '#bump_major_version' do
    it 'increments major version and saves' do
      expect {
        aspiration.bump_major_version('Major update')
      }.to change { aspiration.reload.semantic_version }.from('1.2.3').to('2.0.0')
    end

    it 'resets minor and patch to 0' do
      aspiration.bump_major_version
      expect(aspiration.semantic_version).to eq('2.0.0')
    end
  end

  describe '#bump_minor_version' do
    it 'increments minor version and saves' do
      expect {
        aspiration.bump_minor_version('Minor update')
      }.to change { aspiration.reload.semantic_version }.from('1.2.3').to('1.3.0')
    end

    it 'resets patch to 0' do
      aspiration.bump_minor_version
      expect(aspiration.semantic_version).to eq('1.3.0')
    end
  end

  describe '#bump_patch_version' do
    it 'increments patch version and saves' do
      expect {
        aspiration.bump_patch_version('Patch update')
      }.to change { aspiration.reload.semantic_version }.from('1.2.3').to('1.2.4')
    end
  end

  describe '#current_version?' do
    it 'returns true for latest version' do
      expect(aspiration.current_version?).to be true
    end

    it 'returns true after updates' do
      aspiration.update!(name: 'Updated Name')
      expect(aspiration.current_version?).to be true
    end
  end

  describe '#deprecated?' do
    it 'returns false for current version' do
      expect(aspiration.deprecated?).to be false
    end

    it 'returns true when not current' do
      # Mock the current_version? method to return false
      allow(aspiration).to receive(:current_version?).and_return(false)
      expect(aspiration.deprecated?).to be true
    end
  end

  describe '#display_name_with_version' do
    it 'returns name with version for models with name attribute' do
      expect(aspiration.display_name_with_version).to eq("#{aspiration.name} v1.2.3")
    end

    it 'returns title with version for models with title attribute' do
      assignment = create(:assignment, company: organization, semantic_version: '2.1.0')
      expect(assignment.display_name_with_version).to eq("#{assignment.title} v2.1.0")
    end
  end

  describe '#version_with_guidance' do
    it 'returns display_name_with_version when no versions exist' do
      # Clear versions by creating a new record
      new_aspiration = Aspiration.new(
        organization: organization,
        name: 'New Aspiration',
        semantic_version: '1.0.0',
        sort_order: 1
      )
      new_aspiration.save(validate: false) # Skip validations to avoid triggering paper_trail
      
      expect(new_aspiration.version_with_guidance).to eq(new_aspiration.display_name_with_version)
    end

    it 'returns display_name_with_version when versions exist' do
      aspiration.update!(name: 'Updated')
      expect(aspiration.version_with_guidance).to eq(aspiration.display_name_with_version)
    end
  end

  describe 'validations' do
    it 'validates semantic_version presence' do
      aspiration.semantic_version = nil
      expect(aspiration).not_to be_valid
      expect(aspiration.errors[:semantic_version]).to include("can't be blank")
    end

    it 'validates semantic_version format' do
      aspiration.semantic_version = 'invalid'
      expect(aspiration).not_to be_valid
      expect(aspiration.errors[:semantic_version]).to include('must be in semantic version format (e.g., 1.0.0)')
    end

    it 'accepts valid semantic version format' do
      aspiration.semantic_version = '1.2.3'
      expect(aspiration).to be_valid
    end

    it 'accepts semantic version with zeros' do
      aspiration.semantic_version = '0.0.1'
      expect(aspiration).to be_valid
    end

    it 'accepts multi-digit version numbers' do
      aspiration.semantic_version = '10.25.100'
      expect(aspiration).to be_valid
    end

    it 'rejects partial version numbers' do
      aspiration.semantic_version = '1.2'
      expect(aspiration).not_to be_valid
    end

    it 'rejects version with extra parts' do
      aspiration.semantic_version = '1.2.3.4'
      expect(aspiration).not_to be_valid
    end
  end
end

