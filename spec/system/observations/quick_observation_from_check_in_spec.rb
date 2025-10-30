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
      
      # Should show the pre-populated assignment
      expect(page).to have_content(assignment.title)
      expect(page).to have_content('Assignments') # Section header
      
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

    it 'allows adding rateables to a draft observation and preserves story and feelings' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))
      
      click_link 'Add Win / Challenge'
      
      # Should navigate to quick_new page
      expect(page).to have_content('Create Quick Observation')
      
      # Fill in story and feelings
      fill_in 'observation_story', with: 'Test story that should persist'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      select '😊 (Satisfied) Satisfied', from: 'observation[secondary_feeling]'
      
      # Verify fields are filled
      expect(find_field('observation_story').value).to include('Test story')
      expect(find_field('observation[primary_feeling]').value).to eq('happy')
      expect(find_field('observation[secondary_feeling]').value).to eq('satisfied')
      
      # Click "Add Assignments" button - should auto-save and navigate to add_assignments page
      click_button 'Add Assignments'
      
      # Should be on add_assignments page (after auto-save)
      expect(page).to have_content('Select Assignments to Add', wait: 5)
      
      # Verify story and feelings were saved in database after auto-save
      draft = Observation.drafts.last
      draft.reload
      expect(draft.story).to include('Test story'), "Story not saved after clicking Add Assignments: '#{draft.story}'"
      expect(draft.primary_feeling).to eq('happy'), "Primary feeling not saved: '#{draft.primary_feeling}'"
      expect(draft.secondary_feeling).to eq('satisfied'), "Secondary feeling not saved: '#{draft.secondary_feeling}'"
      
      # Select the assignment
      check "assignment_#{assignment.id}"
      
      # Submit the form - it's a standard form on the page
      click_button 'Add Selected Assignments'
      
      # Should redirect back to quick_new page
      expect(page).to have_content('Create Quick Observation', wait: 5)
      
      # Wait for page to fully load
      expect(page).to have_field('observation_story', wait: 5)
      expect(page).to have_field('observation[primary_feeling]', wait: 5)
      expect(page).to have_field('observation[secondary_feeling]', wait: 5)
      
      # CRITICAL: Story should still be visible in the form field!
      story_value = find_field('observation_story').value
      expect(story_value).to include('Test story'), 
        "Story was lost after adding assignments! Form field value: '#{story_value.inspect}'"
      
      # CRITICAL: Primary feeling should still be selected in the form!
      primary_value = find_field('observation[primary_feeling]').value
      expect(primary_value).to eq('happy'),
        "Primary feeling was lost! Form field value: '#{primary_value.inspect}', expected: 'happy'"
      
      # CRITICAL: Secondary feeling should still be selected in the form!
      secondary_value = find_field('observation[secondary_feeling]').value
      expect(secondary_value).to eq('satisfied'),
        "Secondary feeling was lost! Form field value: '#{secondary_value.inspect}', expected: 'satisfied'"
      
      # Check draft in database
      draft = Observation.drafts.last
      draft.reload
      
      # Assignment should be added to draft
      expect(draft.assignments).to include(assignment)
      
      # Story and feelings should persist in database
      expect(draft.story).to include('Test story'), "Story lost in database: '#{draft.story}'"
      expect(draft.primary_feeling).to eq('happy'), "Primary feeling lost in database: '#{draft.primary_feeling}'"
      expect(draft.secondary_feeling).to eq('satisfied'), "Secondary feeling lost in database: '#{draft.secondary_feeling}'"
      
      # Should still be a draft
      expect(draft.published_at).to be_nil
    end

    it 'saves rating when selecting rating button and submitting form' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))

      click_link 'Add Win / Challenge'

      expect(page).to have_content('Create Quick Observation')

      # Assignment should be pre-populated from the check-in link
      expect(page).to have_content(assignment.title)

      # Fill in story (required before we can save)
      fill_in 'observation_story', with: 'Test rating story'
      
      # Find the radio button for "strongly agree" rating for this assignment
      # The input name should be: observation[observation_ratings_attributes][assignment_#{assignment.id}][rating]
      rating_input_name = "observation[observation_ratings_attributes][assignment_#{assignment.id}][rating]"
      
      # Select the strongly_agree rating radio button
      choose rating_input_name, option: 'strongly_agree'
      
      # Now publish the observation (which will save the rating)
      click_button 'Publish & Return to Check-ins'

      # Wait for redirect
      expect(page).to have_content('Check-Ins', wait: 5)

      # Check that rating was saved in database
      observation = Observation.last
      observation.reload
      
      rating = observation.observation_ratings.find_by(rateable_type: 'Assignment', rateable_id: assignment.id)
      expect(rating).to be_present, "Rating not found for assignment #{assignment.id}. Existing ratings: #{observation.observation_ratings.map { |r| "#{r.rateable_type}:#{r.rateable_id}" }.inspect}"
      expect(rating.rating).to eq('strongly_agree'), "Rating was not strongly_agree, got: #{rating.rating.inspect}"
    end

    it 'persists return_text parameter through add assignments flow' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))
      
      click_link 'Add Win / Challenge'
      
      expect(page).to have_content('Create Quick Observation')
      expect(page).to have_button('Publish & Return to Check-ins')
      
      # Fill in story
      fill_in 'observation_story', with: 'Story that should persist'
      
      # Click Add Assignments - should maintain return_text
      click_button 'Add Assignments'
      
      expect(page).to have_content('Select Assignments to Add', wait: 5)
      
      # Go back - use the return link in overlay header (text is "Draft")
      within('.overlay-header') do
        click_link 'Draft'
      end
      
      # Should still say "Publish & Return to Check-ins"
      expect(page).to have_button('Publish & Return to Check-ins', wait: 5)
      
      # Select assignment and add
      click_button 'Add Assignments'
      check "assignment_#{assignment.id}"
      click_button 'Add Selected Assignments'
      
      # Should still say "Publish & Return to Check-ins" after adding assignments
      expect(page).to have_button('Publish & Return to Check-ins', wait: 5)
      expect(page).to have_field('observation_story', with: 'Story that should persist')
    end

    it 'saves draft when canceling with story content, then redirects' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))
      
      click_link 'Add Win / Challenge'
      
      expect(page).to have_content('Create Quick Observation')
      
      # Fill in story (but don't click Add Assignments or Publish)
      fill_in 'observation_story', with: 'Story that should be saved as draft on cancel'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      
      # Click Cancel button
      click_button 'Cancel'
      
      # Should redirect back to check-ins (not show any error)
      expect(page).to have_content('Check-Ins', wait: 5)
      
      # Verify draft was saved in database
      draft = Observation.drafts.last
      expect(draft).to be_present
      draft.reload
      expect(draft.story).to include('saved as draft on cancel')
      expect(draft.primary_feeling).to eq('happy')
      expect(draft.published_at).to be_nil # Should still be a draft
    end

    it 'handles adding assignments when assignment is pre-populated from check-in link' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))

      click_link 'Add Win / Challenge'

      expect(page).to have_content('Create Quick Observation')

      # Assignment should be pre-populated from the check-in link
      expect(page).to have_content(assignment.title)

      # Fill in story
      fill_in 'observation_story', with: 'Test story with pre-populated assignment'

      # Click "Add Assignments" button - should NOT show validation error about duplicate
      click_button 'Add Assignments'

      # Should be on add_assignments page without validation errors
      expect(page).to have_content('Select Assignments to Add', wait: 5)
      expect(page).not_to have_content('has already been taken')
      expect(page).not_to have_content('errors')

      # Assignment should be pre-checked since it was pre-populated
      expect(page).to have_checked_field("assignment_#{assignment.id}")

      # Uncheck and re-check (or just submit with it checked)
      click_button 'Add Selected Assignments'

      # Should redirect back without errors
      expect(page).to have_content('Create Quick Observation', wait: 5)
      expect(page).not_to have_content('has already been taken')

      # Verify the assignment is still in the draft
      draft = Observation.drafts.last
      draft.reload
      expect(draft.assignments).to include(assignment)
    end

    it 'does not save draft when canceling without story content' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))
      
      click_link 'Add Win / Challenge'
      
      expect(page).to have_content('Create Quick Observation')
      
      # Don't fill in anything, just click Cancel
      click_button 'Cancel'
      
      # Should redirect back to check-ins
      expect(page).to have_content('Check-Ins', wait: 5)
      
      # Verify no draft was created when canceling without story content
      recent_drafts = Observation.drafts.where(observer: employee).order(created_at: :desc).limit(1)
      # Allow some time for any pending database writes
      sleep 0.5
      expect(recent_drafts.count).to eq(0), "No draft should be created when canceling without story content"
    end

    it 'allows primary feeling without secondary feeling when adding assignments' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))
      
      click_link 'Add Win / Challenge'
      
      expect(page).to have_content('Create Quick Observation')
      
      # Fill in story and primary feeling only (NO secondary feeling)
      fill_in 'observation_story', with: 'Test story with primary feeling only'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      # Deliberately NOT selecting secondary feeling
      
      # Verify fields are filled
      expect(find_field('observation_story').value).to include('Test story')
      expect(find_field('observation[primary_feeling]').value).to eq('happy')
      expect(find_field('observation[secondary_feeling]').value).to eq('') # Should be empty/blank
      
      # Click "Add Assignments" - should NOT error and should preserve story/feelings
      click_button 'Add Assignments'
      
      # Should not have validation errors
      expect(page).not_to have_content('Secondary feeling is not included in the list')
      expect(page).not_to have_content('errors')
      
      # Should be on add_assignments page
      expect(page).to have_content('Select Assignments to Add', wait: 5)
      
      # Go back to draft - use the return link in overlay header (text is "Draft")
      within('.overlay-header') do
        click_link 'Draft'
      end
      
      # Story and primary feeling should still be there
      expect(page).to have_field('observation_story', with: 'Test story with primary feeling only', wait: 5)
      expect(find_field('observation[primary_feeling]').value).to eq('happy')
      # Secondary feeling should still be blank
      expect(find_field('observation[secondary_feeling]').value).to eq('')
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
      
      # Should see observation count link (text includes "1 observation" and "ago")
      expect(page).to have_text(/1 observation.*ago/i)
      observation_link = page.find('a', text: /1 observation/i)
      expect(observation_link).to have_css('i.bi.bi-eye')
      
      # Click it
      observation_link.click
      
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

