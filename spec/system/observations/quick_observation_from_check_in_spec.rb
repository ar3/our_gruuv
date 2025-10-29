require 'rails_helper'

RSpec.describe 'Quick Observation from Check-in Flow', type: :system, js: true do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person, full_name: 'Manager Person') }
  let(:employee) { create(:person, full_name: 'Employee Person') }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization, can_manage_employment: true) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 1.month.ago) }

  before do
    manager_teammate
    employee_teammate
    assignment
    assignment_tenure
  end

  context 'as an employee viewing their check-ins' do
    it 'allows creating a quick observation from check-in page' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))
      
      # Should see assignment check-in
      expect(page).to have_content(assignment.title)
      
      # Should see "Add Win / Challenge" button
      expect(page).to have_link('Add Win / Challenge')
      
      # Click the button
      click_link 'Add Win / Challenge'
      
      # Should navigate to quick_new page
      expect(page).to have_content('Create Quick Observation')
      expect(page).to have_content('Observation Details')
      
      # Should show selected observee
      expect(page).to have_content(employee.display_name)
      
      # Fill in story
      fill_in 'observation_story', with: 'I completed a great feature this week!'
      
      # Select a feeling - using the display value with emoji
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      
      # Publish the observation
      expect(page).to have_button('Publish & Return to Check-ins')
      
      # Count observations before clicking
      initial_count = Observation.count
      
      click_button 'Publish & Return to Check-ins'
      
      # Wait for redirect - should go to check-ins page
      expect(page).to have_content('Check-Ins', wait: 5)
      
      # Observation should be published
      observation = Observation.last
      expect(observation).to be_present
      observation.reload
      expect(observation.published_at).to be_present
      expect(observation.story).to include('great feature')
    end

    it 'allows adding rateables to a draft observation and auto-saves story' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))
      
      click_link 'Add Win / Challenge'
      
      # Should navigate to quick_new page
      expect(page).to have_content('Create Quick Observation')
      
      # Fill in the story
      fill_in 'observation_story', with: 'Test story that should persist'
      
      # Get initial draft
      initial_draft = Observation.drafts.last
      initial_draft.reload
      puts "Story BEFORE save: #{initial_draft.story.inspect}"
      
      # Save the story first
      click_button 'Save Story'
      
      # Wait for save to complete - should redirect back
      expect(page).to have_content('Create Quick Observation', wait: 5)
      
      # Verify story is in database
      draft = Observation.drafts.last
      draft.reload
      puts "Story AFTER save: #{draft.story.inspect}"
      expect(draft.story).to include('Test story'), "Story not saved: '#{draft.story}'"
      
      # Now click "Add Assignments" link - navigates to add_assignments page
      click_link 'Add Assignments'
      
      # Should be on add_assignments page
      expect(page).to have_content('Select Assignments to Add')
      
      # Select the assignment
      check "assignment_#{assignment.id}"
      
      # Submit the form - it's a standard form on the page
      click_button 'Add Selected Assignments'
      
      # Should redirect back to quick_new page
      expect(page).to have_content('Create Quick Observation', wait: 5)
      
      # Wait for redirect to complete
      sleep 1
      
      # CRITICAL: Story should still be there!
      story_field = find_field('observation_story', wait: 3)
      expect(story_field.value).to include('Test story'), 
        "Story was lost! Current value: #{story_field.value.inspect}"
      
      # Check draft
      draft = Observation.drafts.last
      draft.reload
      
      # Assignment should be added to draft
      expect(draft.assignments).to include(assignment)
      
      # Story should persist in database
      expect(draft.story).to include('Test story')
      
      # Should still be a draft
      expect(draft.published_at).to be_nil
    end

    it 'shows observation count button if observations exist' do
      # Create a published observation
      published_obs = create(:observation, 
                             observer: manager, 
                             company: organization, 
                             published_at: 1.week.ago)
      published_obs.observees.create!(teammate: employee_teammate)
      published_obs.observation_ratings.create!(
        rateable_type: 'Assignment',
        rateable_id: assignment.id,
        rating: 'strongly_agree'
      )
      
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))
      
      # Should see observation count button
      expect(page).to have_button('1 observation')
      
      # Click it
      click_button '1 observation'
      
      # Should open modal
      expect(page).to have_css('.modal.show')
      expect(page).to have_content('Observations for')
    end
  end

  context 'as a manager viewing employee check-ins' do
    it 'allows creating an observation about the employee' do
      sign_in_and_visit(manager, organization, organization_person_check_ins_path(organization, employee))
      
      # Click "Add Win / Challenge" for the employee
      click_link 'Add Win / Challenge'
      
      # Should show manager as observing employee
      expect(page).to have_content(manager.display_name)
      expect(page).to have_content('Observation Details')
      
      # Fill in story
      fill_in 'story', with: 'Sarah did great work on the project this week!'
      
      # Publish
      click_link 'Publish'
      
      # Should return to check-ins
      expect(page).to have_content('Check-Ins for')
      
      # Observation should be published
      observation = Observation.last
      expect(observation.observer).to eq(manager)
      expect(observation.published_at).to be_present
      expect(observation.observed_teammates).to include(employee_teammate)
    end
  end
end

