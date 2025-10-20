require 'rails_helper'

RSpec.describe Enm::AssessmentPhase1Form do
  let(:assessment) { create(:enm_assessment, :incomplete) }
  let(:form) { Enm::AssessmentPhase1Form.new(assessment) }
  
  describe 'validations' do
    it 'validates presence of core openness same-sex data' do
      form.core_openness_same_sex = nil
      expect(form).not_to be_valid
      expect(form.errors[:core_openness_same_sex]).to include("can't be blank")
    end
    
    it 'validates presence of core openness opposite-sex data' do
      form.core_openness_opposite_sex = nil
      expect(form).not_to be_valid
      expect(form.errors[:core_openness_opposite_sex]).to include("can't be blank")
    end
    
    it 'validates presence of passive openness emotional data' do
      form.passive_openness_emotional = nil
      expect(form).not_to be_valid
      expect(form.errors[:passive_openness_emotional]).to include("can't be blank")
    end
    
    it 'validates presence of passive openness physical data' do
      form.passive_openness_physical = nil
      expect(form).not_to be_valid
      expect(form.errors[:passive_openness_physical]).to include("can't be blank")
    end
    
    it 'validates presence of active readiness emotional data' do
      form.active_readiness_emotional = nil
      expect(form).not_to be_valid
      expect(form.errors[:active_readiness_emotional]).to include("can't be blank")
    end
    
    it 'validates presence of active readiness physical data' do
      form.active_readiness_physical = nil
      expect(form).not_to be_valid
      expect(form.errors[:active_readiness_physical]).to include("can't be blank")
    end
  end
  
  describe 'phase_1_data' do
    it 'returns structured data for phase 1' do
      form.core_openness_same_sex = 2
      form.core_openness_opposite_sex = 2
      form.passive_openness_emotional = 2
      form.passive_openness_physical = 2
      form.active_readiness_emotional = 3
      form.active_readiness_physical = 3
      
      data = form.phase_1_data
      
      expect(data[:core_openness]).to eq({ same_sex: 2, opposite_sex: 2 })
      expect(data[:passive_openness]).to eq({ emotional: 2, physical: 2 })
      expect(data[:active_readiness]).to eq({ emotional: 3, physical: 3 })
    end
  end
end
