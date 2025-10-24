require_relative '../../spec_helper'

RSpec.describe Enm::CodeGeneratorService do
  describe '.generate_unique_code' do
    it 'generates an 8-character alphanumeric code' do
      code = Enm::CodeGeneratorService.generate_unique_code(EnmAssessment)
      
      expect(code).to match(/\A[A-Z0-9]{8}\z/)
    end
    
    it 'generates unique codes' do
      codes = 10.times.map { Enm::CodeGeneratorService.generate_unique_code(EnmAssessment) }
      
      expect(codes.uniq.length).to eq(10)
    end
    
    it 'ensures uniqueness against existing records' do
      existing_assessment = create(:enm_assessment, code: 'ABC12345')
      
      # Mock SecureRandom to return the existing code first, then a new one
      allow(SecureRandom).to receive(:alphanumeric).with(8).and_return('ABC12345', 'XYZ98765')
      
      code = Enm::CodeGeneratorService.generate_unique_code(EnmAssessment)
      
      expect(code).to eq('XYZ98765')
    end
    
    it 'works with different model classes' do
      assessment_code = Enm::CodeGeneratorService.generate_unique_code(EnmAssessment)
      partnership_code = Enm::CodeGeneratorService.generate_unique_code(EnmPartnership)
      
      expect(assessment_code).to match(/\A[A-Z0-9]{8}\z/)
      expect(partnership_code).to match(/\A[A-Z0-9]{8}\z/)
      expect(assessment_code).not_to eq(partnership_code)
    end
  end
end




