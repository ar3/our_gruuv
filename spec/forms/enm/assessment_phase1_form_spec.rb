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
    
    it 'validates presence of passive emotional same-sex data' do
      form.passive_emotional_same_sex = nil
      expect(form).not_to be_valid
      expect(form.errors[:passive_emotional_same_sex]).to include("can't be blank")
    end
    
    it 'validates presence of passive emotional opposite-sex data' do
      form.passive_emotional_opposite_sex = nil
      expect(form).not_to be_valid
      expect(form.errors[:passive_emotional_opposite_sex]).to include("can't be blank")
    end
    
    it 'validates presence of passive physical same-sex data' do
      form.passive_physical_same_sex = nil
      expect(form).not_to be_valid
      expect(form.errors[:passive_physical_same_sex]).to include("can't be blank")
    end
    
    it 'validates presence of passive physical opposite-sex data' do
      form.passive_physical_opposite_sex = nil
      expect(form).not_to be_valid
      expect(form.errors[:passive_physical_opposite_sex]).to include("can't be blank")
    end
    
    it 'validates presence of active emotional same-sex data' do
      form.active_emotional_same_sex = nil
      expect(form).not_to be_valid
      expect(form.errors[:active_emotional_same_sex]).to include("can't be blank")
    end
    
    it 'validates presence of active emotional opposite-sex data' do
      form.active_emotional_opposite_sex = nil
      expect(form).not_to be_valid
      expect(form.errors[:active_emotional_opposite_sex]).to include("can't be blank")
    end
    
    it 'validates presence of active physical same-sex data' do
      form.active_physical_same_sex = nil
      expect(form).not_to be_valid
      expect(form.errors[:active_physical_same_sex]).to include("can't be blank")
    end
    
    it 'validates presence of active physical opposite-sex data' do
      form.active_physical_opposite_sex = nil
      expect(form).not_to be_valid
      expect(form.errors[:active_physical_opposite_sex]).to include("can't be blank")
    end
  end
  
  describe 'phase_1_data' do
    it 'returns structured data for phase 1' do
      form.core_openness_same_sex = 2
      form.core_openness_opposite_sex = 2
      form.passive_emotional_same_sex = 2
      form.passive_emotional_opposite_sex = 2
      form.passive_physical_same_sex = 2
      form.passive_physical_opposite_sex = 2
      form.active_emotional_same_sex = 3
      form.active_emotional_opposite_sex = 3
      form.active_physical_same_sex = 3
      form.active_physical_opposite_sex = 3
      
      data = form.phase_1_data
      
      expect(data[:core_openness]).to eq({ same_sex: 2, opposite_sex: 2 })
      expect(data[:passive_emotional]).to eq({ same_sex: 2, opposite_sex: 2 })
      expect(data[:passive_physical]).to eq({ same_sex: 2, opposite_sex: 2 })
      expect(data[:active_emotional]).to eq({ same_sex: 3, opposite_sex: 3 })
      expect(data[:active_physical]).to eq({ same_sex: 3, opposite_sex: 3 })
    end
  end
end
