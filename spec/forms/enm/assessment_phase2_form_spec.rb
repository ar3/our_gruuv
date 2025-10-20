require 'rails_helper'

RSpec.describe Enm::AssessmentPhase2Form do
  let(:assessment) { create(:enm_assessment, :incomplete) }
  let(:form) { Enm::AssessmentPhase2Form.new(assessment) }
  
  describe 'validations' do
    it 'validates presence of emotional escalator step 1 data' do
      form.emotional_escalator_1_comfort = nil
      expect(form).not_to be_valid
      expect(form.errors[:emotional_escalator_1_comfort]).to include("can't be blank")
    end
    
    it 'validates presence of emotional escalator step 2 data' do
      form.emotional_escalator_2_comfort = nil
      expect(form).not_to be_valid
      expect(form.errors[:emotional_escalator_2_comfort]).to include("can't be blank")
    end
    
    it 'validates presence of all 9 emotional escalator steps' do
      (1..9).each do |step|
        form.send("emotional_escalator_#{step}_comfort=", nil)
      end
      expect(form).not_to be_valid
      (1..9).each do |step|
        expect(form.errors["emotional_escalator_#{step}_comfort".to_sym]).to include("can't be blank")
      end
    end
  end
  
  describe 'phase_2_data' do
    it 'returns structured data for phase 2' do
      (1..9).each do |step|
        form.send("emotional_escalator_#{step}_comfort=", step)
      end
      
      data = form.phase_2_data
      
      expect(data[:emotional_escalator]).to be_an(Array)
      expect(data[:emotional_escalator].length).to eq(9)
      expect(data[:emotional_escalator].first[:step]).to eq(1)
      expect(data[:emotional_escalator].first[:comfort]).to eq(1)
    end
  end
end