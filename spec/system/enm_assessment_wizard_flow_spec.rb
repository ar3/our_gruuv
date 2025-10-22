require 'rails_helper'

RSpec.describe 'ENM Assessment Wizard Flow', type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  describe 'Complete 3-phase assessment flow' do
    it 'guides user through all phases and generates final typology code' do
      # Start at the ENM home page
      visit '/enm'
      
      expect(page).to have_content('ENM Alignment Typology')
      expect(page).to have_content('Take Individual Assessment')
      expect(page).to have_content('Analyze Partnership')
      
      # Click to start assessment
      click_link 'Start Assessment'
      
      # Should redirect to Phase 1
      expect(page).to have_content('Assessment Phase 1')
      expect(page).to have_content('Core Openness')
      
      # Phase 1: Fill out core orientation questions
      within 'form' do
        # Core Openness - Same-sex relationships
        select 'Agree', from: 'enm_assessment_phase1[core_openness_same_sex]'
        
        # Core Openness - Opposite-sex relationships  
        select 'Agree', from: 'enm_assessment_phase1[core_openness_opposite_sex]'
        
        # Passive Emotional Openness
        select 'Agree', from: 'enm_assessment_phase1[passive_emotional_same_sex]'
        select 'Agree', from: 'enm_assessment_phase1[passive_emotional_opposite_sex]'
        
        # Passive Physical Openness
        select 'Agree', from: 'enm_assessment_phase1[passive_physical_same_sex]'
        select 'Agree', from: 'enm_assessment_phase1[passive_physical_opposite_sex]'
        
        # Active Emotional Readiness
        select 'Strongly Agree', from: 'enm_assessment_phase1[active_emotional_same_sex]'
        select 'Strongly Agree', from: 'enm_assessment_phase1[active_emotional_opposite_sex]'
        
        # Active Physical Readiness
        select 'Strongly Agree', from: 'enm_assessment_phase1[active_physical_same_sex]'
        select 'Strongly Agree', from: 'enm_assessment_phase1[active_physical_opposite_sex]'
      end
      
      # Submit Phase 1
      click_button 'Continue'
      
      # Should redirect to Phase 2
      expect(page).to have_content('Assessment Phase 2')
      expect(page).to have_content('Emotional Intimacy Steps')
      
      # Phase 2: Fill out escalator comfort levels and disclosure preferences
      within 'form' do
        # Fill in distant steps (1-3) - used for both physical and emotional
        (1..3).each do |step|
          select 'Comfortable', from: "enm_assessment_phase2[distant_step_#{step}_comfort_same_sex]"
          select 'Comfortable', from: "enm_assessment_phase2[distant_step_#{step}_comfort_opposite_sex]"
          select 'Notification Expected', from: "enm_assessment_phase2[distant_step_#{step}_pre_disclosure_same_sex]"
          select 'Notification Expected', from: "enm_assessment_phase2[distant_step_#{step}_pre_disclosure_opposite_sex]"
          select 'Full, Expected', from: "enm_assessment_phase2[distant_step_#{step}_post_disclosure_same_sex]"
          select 'Full, Expected', from: "enm_assessment_phase2[distant_step_#{step}_post_disclosure_opposite_sex]"
        end
        
        # Fill in physical escalator steps (4-9)
        (4..9).each do |step|
          select 'Comfortable', from: "enm_assessment_phase2[physical_step_#{step}_comfort_same_sex]"
          select 'Comfortable', from: "enm_assessment_phase2[physical_step_#{step}_comfort_opposite_sex]"
          select 'Agreement Expected', from: "enm_assessment_phase2[physical_step_#{step}_pre_disclosure_same_sex]"
          select 'Agreement Expected', from: "enm_assessment_phase2[physical_step_#{step}_pre_disclosure_opposite_sex]"
          select 'Desired, but not Expected', from: "enm_assessment_phase2[physical_step_#{step}_post_disclosure_same_sex]"
          select 'Desired, but not Expected', from: "enm_assessment_phase2[physical_step_#{step}_post_disclosure_opposite_sex]"
        end
        
        # Fill in emotional escalator steps (4-9)
        (4..9).each do |step|
          select 'Comfortable', from: "enm_assessment_phase2[emotional_step_#{step}_comfort_same_sex]"
          select 'Comfortable', from: "enm_assessment_phase2[emotional_step_#{step}_comfort_opposite_sex]"
          select 'Agreement Expected', from: "enm_assessment_phase2[emotional_step_#{step}_pre_disclosure_same_sex]"
          select 'Agreement Expected', from: "enm_assessment_phase2[emotional_step_#{step}_pre_disclosure_opposite_sex]"
          select 'Desired, but not Expected', from: "enm_assessment_phase2[emotional_step_#{step}_post_disclosure_same_sex]"
          select 'Desired, but not Expected', from: "enm_assessment_phase2[emotional_step_#{step}_post_disclosure_opposite_sex]"
        end
      end
      
      # Submit Phase 2
      click_button 'Continue'
      
      # Should redirect to Phase 3
      expect(page).to have_content('Assessment Phase 3')
      expect(page).to have_content('Confirm Results')
      
      # Phase 3: Should show the generated code and typology
      expect(page).to have_content('Your code:')
      expect(page).to have_content('Typology:')
      
      # Submit Phase 3
      click_button 'Continue'
      
      # Should redirect to results page
      expect(page).to have_content('Assessment Results')
      expect(page).to have_content('Your assessment code:')
      
      # Should show the final typology code (should be P-A-K based on our inputs)
      expect(page).to have_content('P-A-K')
      
      # Should show typology description
      expect(page).to have_content('Polysecure Networkers')
      
      # Should have action buttons
      expect(page).to have_link('Update Answers')
      expect(page).to have_link('Add to Partnership Analysis')
      
      # Verify assessment was saved to database
      assessment = EnmAssessment.last
      expect(assessment).to be_present
      expect(assessment.completed_phase).to eq(3)
      expect(assessment.full_code).to eq('P-A-K')
      expect(assessment.code).to match(/\A[A-Z0-9]{8}\z/)
    end

    it 'allows user to update answers after completion' do
      # Create a completed assessment first
      assessment = create(:enm_assessment, :poly_leaning)
      
      # Visit the results page
      visit "/enm/assessments/#{assessment.code}"
      
      expect(page).to have_content('Assessment Results')
      expect(page).to have_content(assessment.full_code)
      
      # Click to update answers
      click_link 'Update Answers'
      
      # Should go to edit page
      expect(page).to have_content('Edit Assessment')
      expect(page).to have_content('Update your assessment answers')
      
      # Should be able to submit updates
      click_button 'Update Assessment'
      
      # Should redirect back to results
      expect(page).to have_content('Assessment Results')
    end

    it 'allows user to add assessment to partnership analysis' do
      # Create a completed assessment
      assessment = create(:enm_assessment, :poly_leaning)
      
      # Visit the results page
      visit "/enm/assessments/#{assessment.code}"
      
      # Click to add to partnership analysis
      click_link 'Add to Partnership Analysis'
      
      # Should go to partnership creation page
      expect(page).to have_content('Create Partnership Analysis')
      expect(page).to have_content('Assessment codes')
      
      # Should have the assessment code field
      within 'form' do
        expect(page).to have_field('enm_partnership[assessment_codes]')
      end
    end
  end

  describe 'Partnership analysis flow' do
    it 'allows creating partnership with multiple assessment codes' do
      # Create some assessments
      assessment1 = create(:enm_assessment, :poly_leaning)
      assessment2 = create(:enm_assessment, :swing_leaning)
      
      # Start partnership creation
      visit '/enm'
      click_link 'Create Partnership Analysis'
      
      expect(page).to have_content('Create Partnership Analysis')
      
      # Enter assessment codes
      within 'form' do
        fill_in 'enm_partnership[assessment_codes]', with: "#{assessment1.code}, #{assessment2.code}"
      end
      
      click_button 'Create Partnership Analysis'
      
      # Should redirect to partnership results
      expect(page).to have_content('Partnership Analysis')
      expect(page).to have_content('Relationship Type')
      expect(page).to have_content('Compatibility Score')
      
      # Should show both assessments
      expect(page).to have_content(assessment1.code)
      expect(page).to have_content(assessment2.code)
      
      # Should have option to add more assessments
      expect(page).to have_field('assessment_code')
      expect(page).to have_button('Add Assessment')
    end
  end

  describe 'Error handling' do
    it 'handles non-existent assessment codes' do
      visit '/enm/assessments/NONEXIST'
      
      # Should show error page
      expect(page).to have_content('ActiveRecord::RecordNotFound')
    end
  end
end