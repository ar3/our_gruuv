require 'rails_helper'

RSpec.describe Enm::AssessmentPhase2Form do
  let(:assessment) { create(:enm_assessment, :incomplete) }
  let(:form) { Enm::AssessmentPhase2Form.new(assessment) }
  
  describe 'validations' do
    # Test distant steps (1-3)
    (1..3).each do |step|
      it "validates presence of distant step #{step} comfort same-sex data" do
        form.send("distant_step_#{step}_comfort_same_sex=", nil)
        expect(form).not_to be_valid
        expect(form.errors["distant_step_#{step}_comfort_same_sex".to_sym]).to include("can't be blank")
      end
      
      it "validates presence of distant step #{step} comfort opposite-sex data" do
        form.send("distant_step_#{step}_comfort_opposite_sex=", nil)
        expect(form).not_to be_valid
        expect(form.errors["distant_step_#{step}_comfort_opposite_sex".to_sym]).to include("can't be blank")
      end
      
      it "validates presence of distant step #{step} pre-disclosure same-sex data" do
        form.send("distant_step_#{step}_pre_disclosure_same_sex=", nil)
        expect(form).not_to be_valid
        expect(form.errors["distant_step_#{step}_pre_disclosure_same_sex".to_sym]).to include("can't be blank")
      end
      
      it "validates presence of distant step #{step} pre-disclosure opposite-sex data" do
        form.send("distant_step_#{step}_pre_disclosure_opposite_sex=", nil)
        expect(form).not_to be_valid
        expect(form.errors["distant_step_#{step}_pre_disclosure_opposite_sex".to_sym]).to include("can't be blank")
      end
      
      it "validates presence of distant step #{step} post-disclosure same-sex data" do
        form.send("distant_step_#{step}_post_disclosure_same_sex=", nil)
        expect(form).not_to be_valid
        expect(form.errors["distant_step_#{step}_post_disclosure_same_sex".to_sym]).to include("can't be blank")
      end
      
      it "validates presence of distant step #{step} post-disclosure opposite-sex data" do
        form.send("distant_step_#{step}_post_disclosure_opposite_sex=", nil)
        expect(form).not_to be_valid
        expect(form.errors["distant_step_#{step}_post_disclosure_opposite_sex".to_sym]).to include("can't be blank")
      end
    end
    
    # Test physical escalator steps (4-9)
    (4..9).each do |step|
      it "validates presence of physical step #{step} comfort same-sex data" do
        form.send("physical_step_#{step}_comfort_same_sex=", nil)
        expect(form).not_to be_valid
        expect(form.errors["physical_step_#{step}_comfort_same_sex".to_sym]).to include("can't be blank")
      end
      
      it "validates presence of physical step #{step} comfort opposite-sex data" do
        form.send("physical_step_#{step}_comfort_opposite_sex=", nil)
        expect(form).not_to be_valid
        expect(form.errors["physical_step_#{step}_comfort_opposite_sex".to_sym]).to include("can't be blank")
      end
    end
    
    # Test emotional escalator steps (4-9)
    (4..9).each do |step|
      it "validates presence of emotional step #{step} comfort same-sex data" do
        form.send("emotional_step_#{step}_comfort_same_sex=", nil)
        expect(form).not_to be_valid
        expect(form.errors["emotional_step_#{step}_comfort_same_sex".to_sym]).to include("can't be blank")
      end
      
      it "validates presence of emotional step #{step} comfort opposite-sex data" do
        form.send("emotional_step_#{step}_comfort_opposite_sex=", nil)
        expect(form).not_to be_valid
        expect(form.errors["emotional_step_#{step}_comfort_opposite_sex".to_sym]).to include("can't be blank")
      end
    end
  end
  
  describe 'phase_2_data' do
    it 'returns structured data for phase 2' do
      # Set up distant steps (1-3)
      (1..3).each do |step|
        form.send("distant_step_#{step}_comfort_same_sex=", 2)
        form.send("distant_step_#{step}_comfort_opposite_sex=", 2)
        form.send("distant_step_#{step}_pre_disclosure_same_sex=", 'notification')
        form.send("distant_step_#{step}_pre_disclosure_opposite_sex=", 'notification')
        form.send("distant_step_#{step}_post_disclosure_same_sex=", 'full')
        form.send("distant_step_#{step}_post_disclosure_opposite_sex=", 'full')
      end
      
      # Set up physical escalator steps (4-9)
      (4..9).each do |step|
        form.send("physical_step_#{step}_comfort_same_sex=", step)
        form.send("physical_step_#{step}_comfort_opposite_sex=", step)
        form.send("physical_step_#{step}_pre_disclosure_same_sex=", 'agreement')
        form.send("physical_step_#{step}_pre_disclosure_opposite_sex=", 'agreement')
        form.send("physical_step_#{step}_post_disclosure_same_sex=", 'desired')
        form.send("physical_step_#{step}_post_disclosure_opposite_sex=", 'desired')
      end
      
      # Set up emotional escalator steps (4-9)
      (4..9).each do |step|
        form.send("emotional_step_#{step}_comfort_same_sex=", step)
        form.send("emotional_step_#{step}_comfort_opposite_sex=", step)
        form.send("emotional_step_#{step}_pre_disclosure_same_sex=", 'agreement')
        form.send("emotional_step_#{step}_pre_disclosure_opposite_sex=", 'agreement')
        form.send("emotional_step_#{step}_post_disclosure_same_sex=", 'desired')
        form.send("emotional_step_#{step}_post_disclosure_opposite_sex=", 'desired')
      end
      
      data = form.phase_2_data
      
      # Test distant steps
      expect(data[:distant_steps]).to be_an(Array)
      expect(data[:distant_steps].length).to eq(3)
      expect(data[:distant_steps].first[:step]).to eq(1)
      expect(data[:distant_steps].first[:comfort]).to eq({ same_sex: 2, opposite_sex: 2 })
      expect(data[:distant_steps].first[:pre_disclosure]).to eq({ same_sex: 'notification', opposite_sex: 'notification' })
      expect(data[:distant_steps].first[:post_disclosure]).to eq({ same_sex: 'full', opposite_sex: 'full' })
      
      # Test physical escalator
      expect(data[:physical_escalator]).to be_an(Array)
      expect(data[:physical_escalator].length).to eq(6)
      expect(data[:physical_escalator].first[:step]).to eq(4)
      expect(data[:physical_escalator].first[:comfort]).to eq({ same_sex: 4, opposite_sex: 4 })
      
      # Test emotional escalator
      expect(data[:emotional_escalator]).to be_an(Array)
      expect(data[:emotional_escalator].length).to eq(6)
      expect(data[:emotional_escalator].first[:step]).to eq(4)
      expect(data[:emotional_escalator].first[:comfort]).to eq({ same_sex: 4, opposite_sex: 4 })
    end
  end
end