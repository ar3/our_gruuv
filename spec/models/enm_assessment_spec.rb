require 'rails_helper'

RSpec.describe EnmAssessment, type: :model do
  describe 'validations' do
    it 'requires a unique code' do
      assessment1 = create(:enm_assessment, code: 'ABC12345')
      assessment2 = build(:enm_assessment, code: 'ABC12345')
      
      expect(assessment2).not_to be_valid
      expect(assessment2.errors[:code]).to include('has already been taken')
    end
    
    it 'requires code to be 8 characters' do
      assessment = build(:enm_assessment, code: 'SHORT')
      expect(assessment).not_to be_valid
      expect(assessment.errors[:code]).to include('is the wrong length (should be 8 characters)')
      
      assessment.code = 'TOOLONG123'
      expect(assessment).not_to be_valid
      expect(assessment.errors[:code]).to include('is the wrong length (should be 8 characters)')
    end
    
    it 'requires code to be alphanumeric' do
      assessment = build(:enm_assessment, code: 'ABC-123')
      expect(assessment).not_to be_valid
      expect(assessment.errors[:code]).to include('is invalid')
    end
    
    it 'validates completed_phase is between 1 and 3' do
      assessment = build(:enm_assessment, completed_phase: 0)
      expect(assessment).not_to be_valid
      expect(assessment.errors[:completed_phase]).to include('is not included in the list')
      
      assessment.completed_phase = 4
      expect(assessment).not_to be_valid
      expect(assessment.errors[:completed_phase]).to include('is not included in the list')
    end
    
    it 'validates macro_category is one of the allowed values' do
      assessment = build(:enm_assessment, macro_category: 'INVALID')
      expect(assessment).not_to be_valid
      expect(assessment.errors[:macro_category]).to include('is not included in the list')
    end
    
    it 'validates readiness is one of the allowed values' do
      assessment = build(:enm_assessment, readiness: 'INVALID')
      expect(assessment).not_to be_valid
      expect(assessment.errors[:readiness]).to include('is not included in the list')
    end
    
    it 'validates style is one of the allowed values' do
      assessment = build(:enm_assessment, style: 'INVALID')
      expect(assessment).not_to be_valid
      expect(assessment.errors[:style]).to include('is not included in the list')
    end
  end
  
  describe 'associations' do
    it 'can have many partnerships through assessment_codes' do
      assessment = create(:enm_assessment, code: 'ABC12345')
      partnership = create(:enm_partnership, assessment_codes: ['ABC12345'])
      
      expect(assessment.partnerships).to include(partnership)
    end
  end
  
  describe 'scopes' do
    describe '.completed' do
      it 'returns assessments with completed_phase 3' do
        completed = create(:enm_assessment, completed_phase: 3)
        incomplete = create(:enm_assessment, completed_phase: 2)
        
        expect(EnmAssessment.completed).to include(completed)
        expect(EnmAssessment.completed).not_to include(incomplete)
      end
    end
    
    describe '.by_macro_category' do
      it 'returns assessments filtered by macro category' do
        poly = create(:enm_assessment, macro_category: 'P')
        swing = create(:enm_assessment, macro_category: 'S')
        
        expect(EnmAssessment.by_macro_category('P')).to include(poly)
        expect(EnmAssessment.by_macro_category('P')).not_to include(swing)
      end
    end
  end
  
  describe 'methods' do
    describe '#completed?' do
      it 'returns true when completed_phase is 3' do
        assessment = build(:enm_assessment, completed_phase: 3)
        expect(assessment.completed?).to be true
      end
      
      it 'returns false when completed_phase is less than 3' do
        assessment = build(:enm_assessment, completed_phase: 2)
        expect(assessment.completed?).to be false
      end
    end
    
    describe '#shareable_url' do
      it 'returns the URL for sharing this assessment' do
        assessment = build(:enm_assessment, code: 'ABC12345')
        expect(assessment.shareable_url).to eq('/enm/assessments/ABC12345')
      end
    end
    
    describe '#typology_description' do
      it 'returns the nickname and description for the full code' do
        assessment = build(:enm_assessment, full_code: 'P-A-K')
        description = assessment.typology_description
        
        expect(description[:nickname]).to eq('Polysecure Networkers')
        expect(description[:description]).to include('Emotionally interwoven lovers and friends')
      end
    end
  end
end
