require_relative '../../spec_helper'

RSpec.describe Enm::AssessmentPhase3Form do
  let(:assessment) { create(:enm_assessment, :poly_leaning) }
  let(:form) { Enm::AssessmentPhase3Form.new(assessment) }
  
  describe 'validations' do
    it 'is always valid - no additional input required' do
      expect(form).to be_valid
    end
  end
  
  describe 'phase_3_data' do
    it 'returns confirmation data' do
      data = form.phase_3_data
      
      expect(data[:confirmed]).to be true
    end
  end
end




