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
    it 'retains story, privacy, feelings, rateables, and observees across add flows and on publish' do
      # Setup: second assignment, an ability, an aspiration, and another teammate
      second_assignment = create(:assignment, company: organization)
      create(:assignment_tenure, teammate: employee_teammate, assignment: second_assignment, started_at: 1.month.ago)
      ability = create(:ability, organization: organization, name: 'Ruby')
      aspiration = create(:aspiration, organization: organization, name: 'Grow Leadership')
      other_person = create(:person, full_name: 'Teammate Two')
      other_teammate = create(:teammate, person: other_person, organization: organization)

      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))

      # 1) Start quick_new from assignment row (first assignment is pre-populated)
      first('a', text: 'Add Win / Challenge').click
      expect(page).to have_content('Create Quick Observation')
      
      # First assignment should be visible (pre-populated from check-in link)
      expect(page).to have_content(assignment.title)

      # 2) Fill story, journal privacy, both feelings
      fill_in 'observation_story', with: 'Full flow story validation text'
      choose 'observation_privacy_level_observer_only'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      select '😊 (Satisfied) Satisfied', from: 'observation[secondary_feeling]'
      
      # Set rating for the pre-populated first assignment
      choose "observation[observation_ratings_attributes][assignment_#{assignment.id}][rating]", option: 'strongly_agree'

      # 3) Add a new assignment and set rating to agree
      click_button 'Add Assignments'
      expect(page).to have_content('Select Assignments to Add', wait: 5)
      check "assignment_#{second_assignment.id}"
      click_button 'Add Selected Assignments'
      expect(page).to have_content('Create Quick Observation', wait: 5)

      # Set rating for the newly added second assignment to agree
      choose "observation[observation_ratings_attributes][assignment_#{second_assignment.id}][rating]", option: 'agree'
      
      # Verify both assignment ratings are set
      expect(find("input[name='observation[observation_ratings_attributes][assignment_#{assignment.id}][rating]'][value='strongly_agree']")).to be_checked
      expect(find("input[name='observation[observation_ratings_attributes][assignment_#{second_assignment.id}][rating]'][value='agree']")).to be_checked

      # 4) Validate previously filled items are still present
      expect(find_field('observation_story').value).to include('Full flow story validation text')
      expect(page).to have_checked_field('observation_privacy_level_observer_only')
      expect(find_field('observation[primary_feeling]').value).to eq('happy')
      expect(find_field('observation[secondary_feeling]').value).to eq('satisfied')

      # 5) Add a new observee
      find('input[name="save_and_add"][value="observees"]', visible: true).click
      expect(page).to have_content('Select Observees to Add', wait: 5)
      check "teammate_#{other_teammate.id}"
      click_button 'Add Selected Observees'
      expect(page).to have_content('Create Quick Observation', wait: 5)

      # 6) Validate state still intact, including assignment ratings (BUG CHECK)
      expect(find_field('observation_story').value).to include('Full flow story validation text')
      expect(page).to have_checked_field('observation_privacy_level_observer_only')
      expect(find_field('observation[primary_feeling]').value).to eq('happy')
      expect(find_field('observation[secondary_feeling]').value).to eq('satisfied')
      # Ensure the new observee is visible
      expect(page).to have_content(other_person.display_name)
      # CRITICAL: Check that second assignment rating is still set (not reset to N/A)
      expect(find("input[name='observation[observation_ratings_attributes][assignment_#{second_assignment.id}][rating]'][value='agree']")).to be_checked, 
        "Second assignment rating was reset to N/A after adding observee!"
      # First assignment rating should still be set too
      expect(find("input[name='observation[observation_ratings_attributes][assignment_#{assignment.id}][rating]'][value='strongly_agree']")).to be_checked

      # 7) Add ability and set rating to agree
      find('input[name="save_and_add"][value="abilities"]', visible: true).click
      expect(page).to have_content('Select Abilities to Add', wait: 5)
      check "ability_#{ability.id}"
      click_button 'Add Selected Abilities'
      expect(page).to have_content('Create Quick Observation', wait: 5)
      choose "observation[observation_ratings_attributes][ability_#{ability.id}][rating]", option: 'agree'

      # 8) Validate state still intact, including assignment ratings (BUG CHECK)
      expect(find_field('observation_story').value).to include('Full flow story validation text')
      expect(page).to have_checked_field('observation_privacy_level_observer_only')
      expect(find_field('observation[primary_feeling]').value).to eq('happy')
      expect(find_field('observation[secondary_feeling]').value).to eq('satisfied')
      expect(page).to have_content(other_person.display_name)
      # CRITICAL: Check that second assignment rating is still set (not reset to N/A)
      expect(find("input[name='observation[observation_ratings_attributes][assignment_#{second_assignment.id}][rating]'][value='agree']")).to be_checked,
        "Second assignment rating was reset to N/A after adding ability!"
      # First assignment rating should still be set too
      expect(find("input[name='observation[observation_ratings_attributes][assignment_#{assignment.id}][rating]'][value='strongly_agree']")).to be_checked

      # 9) Add aspiration and set rating to agree
      find('input[name="save_and_add"][value="aspirations"]', visible: true).click
      expect(page).to have_content('Select Aspirations to Add', wait: 5)
      check "aspiration_#{aspiration.id}"
      click_button 'Add Selected Aspirations'
      expect(page).to have_content('Create Quick Observation', wait: 5)
      choose "observation[observation_ratings_attributes][aspiration_#{aspiration.id}][rating]", option: 'agree'

      # 10) Validate everything still intact prior to publish, including assignment ratings (BUG CHECK)
      expect(find_field('observation_story').value).to include('Full flow story validation text')
      expect(page).to have_checked_field('observation_privacy_level_observer_only')
      expect(find_field('observation[primary_feeling]').value).to eq('happy')
      expect(find_field('observation[secondary_feeling]').value).to eq('satisfied')
      expect(page).to have_content(other_person.display_name)
      # CRITICAL: Check that second assignment rating is still set (not reset to N/A)
      expect(find("input[name='observation[observation_ratings_attributes][assignment_#{second_assignment.id}][rating]'][value='agree']")).to be_checked,
        "Second assignment rating was reset to N/A after adding aspiration!"
      # First assignment rating should still be set too
      expect(find("input[name='observation[observation_ratings_attributes][assignment_#{assignment.id}][rating]'][value='strongly_agree']")).to be_checked

      # Publish & validate persisted record
      click_button 'Publish & Return to Check-ins'
      expect(page).to have_content('Check-Ins', wait: 5)

      observation = Observation.last
      observation.reload
      expect(observation.story).to include('Full flow story validation text')
      expect(observation.privacy_level).to eq('observer_only')
      expect(observation.primary_feeling).to eq('happy')
      expect(observation.secondary_feeling).to eq('satisfied')
      # Observees include both original employee and added teammate
      expect(observation.observees.pluck(:teammate_id)).to include(employee_teammate.id, other_teammate.id)
      # Ratings - verify all are persisted correctly
      first_assignment_rating = observation.observation_ratings.find_by(rateable_type: 'Assignment', rateable_id: assignment.id)
      second_assignment_rating = observation.observation_ratings.find_by(rateable_type: 'Assignment', rateable_id: second_assignment.id)
      ability_rating = observation.observation_ratings.find_by(rateable_type: 'Ability', rateable_id: ability.id)
      aspiration_rating = observation.observation_ratings.find_by(rateable_type: 'Aspiration', rateable_id: aspiration.id)
      expect(first_assignment_rating&.rating).to eq('strongly_agree')
      expect(second_assignment_rating&.rating).to eq('agree'), 
        "Second assignment rating was not persisted correctly in database!"
      expect(ability_rating&.rating).to eq('agree')
      expect(aspiration_rating&.rating).to eq('agree')
    end
    it 'shows an aspiration preselected via querystring and saves draft only when clicking Add Aspirations' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))

      aspiration = create(:aspiration, organization: organization, name: 'Career Growth')

      # Navigate with preselected aspiration via query string
      visit quick_new_organization_observations_path(
        organization,
        return_url: organization_person_check_ins_path(organization, employee),
        return_text: 'Check-ins',
        observee_ids: [employee_teammate.id],
        rateable_type: 'Aspiration',
        rateable_id: aspiration.id,
        privacy_level: 'observed_and_managers'
      )

      expect(page).to have_content('Create Quick Observation')
      # Preselected aspiration should be visible even before saving draft
      expect(page).to have_content('Aspirations')
      expect(page).to have_content('Career Growth')

      # No draft should be created yet
      expect(Observation.drafts.count).to eq(0)

      # Click Add Aspirations to save draft and go to picker
      find('input[name="save_and_add"][value="aspirations"]', visible: true).click

      # Now on the add aspirations page
      expect(page).to have_content('Select Aspirations to Add', wait: 5)
      # A draft should now exist
      expect(Observation.drafts.count).to eq(1)
    end

    it 'shows an ability preselected via querystring and saves draft only when clicking Add Abilities' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))

      ability = create(:ability, organization: organization, name: 'Ruby')

      visit quick_new_organization_observations_path(
        organization,
        return_url: organization_person_check_ins_path(organization, employee),
        return_text: 'Check-ins',
        observee_ids: [employee_teammate.id],
        rateable_type: 'Ability',
        rateable_id: ability.id,
        privacy_level: 'observed_and_managers'
      )

      expect(page).to have_content('Create Quick Observation')
      expect(page).to have_content('Abilities')
      expect(page).to have_content('Ruby')
      expect(Observation.drafts.count).to eq(0)

      find('input[name="save_and_add"][value="abilities"]', visible: true).click

      expect(page).to have_content('Select Abilities to Add', wait: 5)
      expect(Observation.drafts.count).to eq(1)
    end

    it 'allows adding additional observees via an Add Observees flow and only saves on click' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))

      other_person = create(:person, full_name: 'Teammate Two')
      other_teammate = create(:teammate, person: other_person, organization: organization)

      visit quick_new_organization_observations_path(
        organization,
        return_url: organization_person_check_ins_path(organization, employee),
        return_text: 'Check-ins',
        observee_ids: [employee_teammate.id],
        privacy_level: 'observed_and_managers'
      )

      expect(page).to have_content(employee.display_name)
      expect(Observation.drafts.count).to eq(0)

      find('input[name="save_and_add"][value="observees"]', visible: true).click

      expect(page).to have_content('Select Observees to Add', wait: 5)
      expect(Observation.drafts.count).to eq(1)

      # Check the new teammate and submit
      check "teammate_#{other_teammate.id}"
      click_button 'Add Selected Observees'

      # Back on quick_new; both observees show
      expect(page).to have_content(other_person.display_name)
    end
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
      
      # Wait for the form to be ready before clicking
      expect(page).to have_button('Add Assignments', wait: 5)
      
      # Click Add Assignments - should maintain return_text
      click_button 'Add Assignments'
      
      # Wait for the redirect to complete and the page to be fully loaded
      expect(page).to have_content('Select Assignments to Add', wait: 10)
      
      # Wait a moment for the page to stabilize after redirect
      sleep 0.5
      
      # Go back using the overlay header back button
      expect(page).to have_css('#return-button', wait: 5)
      find('#return-button').click
      
      # Wait for redirect back to quick_new
      expect(page).to have_content('Create Quick Observation', wait: 10)
      
      # Should still say "Publish & Return to Check-ins"
      expect(page).to have_button('Publish & Return to Check-ins', wait: 5)
      
      # Select assignment and add
      expect(page).to have_button('Add Assignments', wait: 5)
      click_button 'Add Assignments'
      
      # Wait for add assignments page
      expect(page).to have_content('Select Assignments to Add', wait: 10)
      sleep 0.5
      
      check "assignment_#{assignment.id}"
      click_button 'Add Selected Assignments'
      
      # Wait for redirect back to quick_new
      expect(page).to have_content('Create Quick Observation', wait: 10)
      
      # Should still say "Publish & Return to Check-ins" after adding assignments
      expect(page).to have_button('Publish & Return to Check-ins', wait: 5)
      expect(page).to have_field('observation_story', with: 'Story that should persist', wait: 5)
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
      
      # Go back using the overlay header back button
      find('#return-button').click
      
      # Story and primary feeling should still be there
      expect(page).to have_field('observation_story', with: 'Test story with primary feeling only', wait: 5)
      expect(find_field('observation[primary_feeling]').value).to eq('happy')
      # Secondary feeling should still be blank
      expect(find_field('observation[secondary_feeling]').value).to eq('')
    end

    it 'handles adding aspirations and prevents duplicates' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))

      click_link 'Add Win / Challenge'

      expect(page).to have_content('Create Quick Observation')

      # Create an aspiration for the org
      aspiration = create(:aspiration, organization: organization)

      # Go to add aspirations
      find('input[name="save_and_add"][value="aspirations"]', visible: true).click
      expect(page).to have_content('Select Aspirations to Add', wait: 5)

      # Check and submit
      check "aspiration_#{aspiration.id}"
      click_button 'Add Selected Aspirations'

      # Back on quick_new, should show aspiration section, no errors
      expect(page).to have_content('Aspirations', wait: 5)
      expect(page).to have_content(aspiration.name)
      expect(page).not_to have_content('has already been taken')

      # Add again to ensure no duplicate validation error
      find('input[name="save_and_add"][value="aspirations"]', visible: true).click
      expect(page).to have_checked_field("aspiration_#{aspiration.id}")
      click_button 'Add Selected Aspirations'
      expect(page).not_to have_content('has already been taken')
    end

    it 'saves rating for an ability and persists it on publish' do
      sign_in_and_visit(employee, organization, organization_person_check_ins_path(organization, employee))

      click_link 'Add Win / Challenge'

      ability = create(:ability, organization: organization)

      # Add ability
      find('input[name="save_and_add"][value="abilities"]', visible: true).click
      expect(page).to have_content('Select Abilities to Add', wait: 5)
      check "ability_#{ability.id}"
      click_button 'Add Selected Abilities'

      # Now rate the ability
      rating_input_name = "observation[observation_ratings_attributes][ability_#{ability.id}][rating]"
      fill_in 'observation_story', with: 'Story for ability rating'
      choose rating_input_name, option: 'agree'

      click_button 'Publish & Return to Check-ins'
      expect(page).to have_content('Check-Ins', wait: 5)

      observation = Observation.last
      observation.reload
      rating = observation.observation_ratings.find_by(rateable_type: 'Ability', rateable_id: ability.id)
      expect(rating).to be_present
      expect(rating.rating).to eq('agree')
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
      
      # Should see observation modal trigger link for this assignment
      expect(page).to have_css('a[data-bs-target^="#observationsModal_assignment_"]', wait: 5)
      observation_link = page.find('a[data-bs-target^="#observationsModal_assignment_"]', match: :first)
      expect(observation_link).to have_css('i.bi.bi-eye')
      
      # Get the modal ID from the link's data-bs-target attribute
      modal_target = observation_link['data-bs-target']
      modal_id = modal_target.gsub('#', '')
      
      # Ensure the modal element exists in the DOM (may be hidden initially)
      expect(page).to have_css("##{modal_id}", visible: :all, wait: 5)
      
      # Use JavaScript to trigger the modal - more reliable than clicking the link
      # Bootstrap 5's getOrCreateInstance handles initialization better
      page.execute_script("
        function showModal() {
          if (typeof bootstrap !== 'undefined' && typeof bootstrap.Modal !== 'undefined') {
            var modalElement = document.getElementById('#{modal_id}');
            if (modalElement) {
              try {
                var modal = bootstrap.Modal.getOrCreateInstance(modalElement);
                modal.show();
                return true;
              } catch (e) {
                var modal = new bootstrap.Modal(modalElement);
                modal.show();
                return true;
              }
            }
          }
          return false;
        }
        showModal();
      ")
      
      # Wait for the modal to become visible
      expect(page).to have_css("##{modal_id}.show", wait: 10)
      
      # Wait for the modal title to be visible and contain the expected text
      within("##{modal_id}.show", visible: true) do
        expect(page).to have_css('h5.modal-title', text: /Observations for/, wait: 5)
      end
    end
  end

  context 'as a manager viewing employee check-ins' do
    it 'allows creating an observation about the employee' do
      sign_in_and_visit(manager, organization, organization_person_check_ins_path(organization, employee))
      
      # Click the first "Add Win / Challenge" (scoped to first occurrence)
      first('a', text: 'Add Win / Challenge').click
      
      # Should show employee being observed
      expect(page).to have_content(employee.display_name)
      expect(page).to have_content('Observation Details')
      
      # Fill in story
      fill_in 'observation_story', with: 'Sarah did great work on the project this week!'
      
      # Publish
      click_button 'Publish & Return to Check-ins'
      
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

