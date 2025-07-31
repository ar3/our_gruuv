require 'rails_helper'

RSpec.describe ExternalReference, type: :model do
  let(:assignment) { create(:assignment) }
  let(:external_reference) { create(:external_reference, referable: assignment) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(external_reference).to be_valid
    end

    it 'requires referable' do
      external_reference.referable = nil
      expect(external_reference).not_to be_valid
    end

    it 'requires reference_type' do
      external_reference.reference_type = nil
      expect(external_reference).not_to be_valid
    end

    it 'allows blank URL' do
      external_reference.url = nil
      expect(external_reference).to be_valid
    end

    it 'allows empty URL' do
      external_reference.url = ''
      expect(external_reference).to be_valid
    end

    describe 'URL format validation' do
      it 'accepts valid URLs' do
        external_reference.url = 'https://docs.google.com/document/d/example'
        expect(external_reference).to be_valid
      end

      it 'accepts HTTP URLs' do
        external_reference.url = 'http://example.com'
        expect(external_reference).to be_valid
      end

      it 'rejects invalid URLs' do
        external_reference.url = 'not-a-url'
        expect(external_reference).not_to be_valid
        expect(external_reference.errors[:url]).to include('must be a valid URL')
      end
    end
  end

  describe 'associations' do
    it 'belongs to a referable' do
      expect(external_reference.referable).to eq(assignment)
    end
  end

  describe 'scopes' do
    let!(:published_ref) { create(:external_reference, :published, referable: assignment) }
    let!(:draft_ref) { create(:external_reference, :draft, referable: assignment) }

    it 'filters by published type' do
      expect(ExternalReference.published).to include(published_ref)
      expect(ExternalReference.published).not_to include(draft_ref)
    end

    it 'filters by draft type' do
      expect(ExternalReference.draft).to include(draft_ref)
      expect(ExternalReference.draft).not_to include(published_ref)
    end
  end

  describe 'instance methods' do
    it 'returns display name' do
      expect(external_reference.display_name).to eq("#{assignment.display_name} (published)")
    end

    it 'returns display name with draft type' do
      draft_ref = create(:external_reference, :draft, referable: assignment)
      expect(draft_ref.display_name).to eq("#{assignment.display_name} (draft)")
    end

    describe '#sync_needed?' do
      it 'returns true when never synced' do
        external_reference.last_synced_at = nil
        expect(external_reference.sync_needed?).to be true
      end

      it 'returns true when synced more than an hour ago' do
        external_reference.last_synced_at = 2.hours.ago
        expect(external_reference.sync_needed?).to be true
      end

      it 'returns false when synced recently' do
        external_reference.last_synced_at = 30.minutes.ago
        expect(external_reference.sync_needed?).to be false
      end
    end
  end
end 