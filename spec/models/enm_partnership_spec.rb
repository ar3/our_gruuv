require 'rails_helper'

RSpec.describe EnmPartnership, type: :model do
  describe 'validations' do
    it 'requires a unique code' do
      partnership1 = create(:enm_partnership, code: 'XYZ98765')
      partnership2 = build(:enm_partnership, code: 'XYZ98765')
      
      expect(partnership2).not_to be_valid
      expect(partnership2.errors[:code]).to include('has already been taken')
    end
    
    it 'requires code to be 8 characters' do
      partnership = build(:enm_partnership, code: 'SHORT')
      expect(partnership).not_to be_valid
      expect(partnership.errors[:code]).to include('is the wrong length (should be 8 characters)')
    end
    
    it 'requires code to be alphanumeric' do
      partnership = build(:enm_partnership, code: 'XYZ-987')
      expect(partnership).not_to be_valid
      expect(partnership.errors[:code]).to include('is invalid')
    end
    
    it 'requires at least one assessment code' do
      partnership = build(:enm_partnership, assessment_codes: [])
      expect(partnership).not_to be_valid
      expect(partnership.errors[:assessment_codes]).to include("can't be empty")
    end
    
    it 'validates relationship_type is one of the allowed values' do
      partnership = build(:enm_partnership, relationship_type: 'INVALID')
      expect(partnership).not_to be_valid
      expect(partnership.errors[:relationship_type]).to include('is not included in the list')
    end
  end
  
  describe 'associations' do
    it 'can access assessments through their codes' do
      assessment1 = create(:enm_assessment, code: 'ABC12345')
      assessment2 = create(:enm_assessment, code: 'DEF67890')
      partnership = create(:enm_partnership, assessment_codes: ['ABC12345', 'DEF67890'])
      
      expect(partnership.assessments).to include(assessment1, assessment2)
    end
  end
  
  describe 'methods' do
    describe '#assessments' do
      it 'returns EnmAssessment records for the stored codes' do
        assessment1 = create(:enm_assessment, code: 'ABC12345')
        assessment2 = create(:enm_assessment, code: 'DEF67890')
        partnership = build(:enm_partnership, assessment_codes: ['ABC12345', 'DEF67890'])
        
        assessments = partnership.assessments
        expect(assessments).to include(assessment1, assessment2)
      end
      
      it 'returns empty array when no assessments found' do
        partnership = build(:enm_partnership, assessment_codes: ['NONEXIST'])
        expect(partnership.assessments).to eq([])
      end
    end
    
    describe '#add_assessment_code' do
      it 'adds a new assessment code to the partnership' do
        partnership = create(:enm_partnership, assessment_codes: ['ABC12345'])
        partnership.add_assessment_code('DEF67890')
        
        expect(partnership.assessment_codes).to include('ABC12345', 'DEF67890')
      end
      
      it 'does not add duplicate codes' do
        partnership = create(:enm_partnership, assessment_codes: ['ABC12345'])
        partnership.add_assessment_code('ABC12345')
        
        expect(partnership.assessment_codes.count('ABC12345')).to eq(1)
      end
    end
    
    describe '#remove_assessment_code' do
      it 'removes an assessment code from the partnership' do
        partnership = create(:enm_partnership, assessment_codes: ['ABC12345', 'DEF67890'])
        partnership.remove_assessment_code('ABC12345')
        
        expect(partnership.assessment_codes).to eq(['DEF67890'])
      end
    end
    
    describe '#shareable_url' do
      it 'returns the URL for sharing this partnership' do
        partnership = build(:enm_partnership, code: 'XYZ98765')
        expect(partnership.shareable_url).to eq('/enm/partnerships/XYZ98765')
      end
    end
    
    describe '#relationship_description' do
      it 'returns the description for the relationship type' do
        partnership = build(:enm_partnership, relationship_type: 'H')
        description = partnership.relationship_description
        
        expect(description).to eq('Hybrid / Bridging Worlds')
      end
    end
  end
end
