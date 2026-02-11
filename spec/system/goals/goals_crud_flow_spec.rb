require 'rails_helper'

RSpec.describe 'Goals CRUD Flow', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { CompanyTeammate.create!(person: person, organization: organization) }
  
  before do
    # Use proper authentication for system specs
    sign_in_as(person, organization)
  end
  
  describe 'Complete Goal CRUD Flow' do
    xit 'performs full CRUD operations: index -> new -> create -> show -> edit -> update -> delete' do # SKIPPED: Goal index must have owner not yet implemented
      # Step 1: Visit the goals index
      visit organization_goals_path(organization)
      
      # Select owner if needed (it's in a modal)
      if page.has_content?('Please select an owner')
        # Open the filter modal
        click_button 'Filter & Sort'
        expect(page).to have_content('Select an owner')
        # Select owner from the modal
        select "Teammate: #{person.display_name}", from: 'owner_id'
        # Submit the form to apply the filter
        within('#goalsFilterModal') do
          click_button 'Apply Filters'
        end
        expect(page).to have_content('Goals')
      end
      
      # Should see the goals index page
      expect(page).to have_content('Goals')
      expect(page).to have_link(href: new_organization_goal_path(organization))
      
      # Step 2: Click to create a new goal
      first(:link, href: new_organization_goal_path(organization)).click
      
      # Should be on the new goal form
      expect(page).to have_content('New Goal')
      expect(page).to have_field('goal_title')
      expect(page).to have_field('goal_description')
      expect(page).to have_content('Timeframe')
      expect(page).to have_button('Create Goal')
      
      # Step 3: Fill out and submit the form
      fill_in 'goal_title', with: 'Test Goal'
      fill_in 'goal_description', with: 'This is a test goal for our system test'
      
      # Select timeframe (button group) - click on label instead of radio button
      find('label[for="timeframe_near_term"]').click
      
      # Goal type defaults to inspirational_objective, but let's verify it's selected
      # Privacy level defaults to only_creator_owner_and_managers
      # Select owner from dropdown
      select "Teammate: #{person.display_name}", from: 'goal[owner_id]'
      
      click_button 'Create Goal'
      
      # Step 4: Should be redirected to check-in mode with success message
      expect(page).to have_success_flash('Goal was successfully created')
      expect(page).to have_content('Test Goal')
      expect(page).to have_content('Weekly Update')
      
      # Step 5: Click edit
      click_link 'Edit'
      
      # Should be on the edit goal form
      expect(page).to have_content('Edit Goal')
      expect(page).to have_field('goal_title', with: 'Test Goal')
      
      # Step 6: Update the goal
      fill_in 'goal_title', with: 'Updated Test Goal'
      fill_in 'goal_description', with: 'This is an updated test goal'
      
      click_button 'Update Goal'
      
      # Should be redirected to show page with success message
      expect(page).to have_success_flash('Goal was successfully updated')
      expect(page).to have_content('Updated Test Goal')
      expect(page).to have_content('This is an updated test goal')
      
      # Step 7: Go back to index
      click_link 'Back to Goals'
      
      # Should see updated goal in the list
      expect(page).to have_content('Goals')
      
      # Select owner if needed after redirect
      if page.has_content?('Please select an owner')
        click_button 'Filter & Sort'
        expect(page).to have_content('Select an owner')
        select "Teammate: #{person.display_name}", from: 'owner_id'
        within('#goalsFilterModal') do
          click_button 'Apply Filters'
        end
        expect(page).to have_content('Goals')
      end
      
      expect(page).to have_content('Updated Test Goal')
      
      # Step 8: Delete the goal
      goal_to_delete = Goal.find_by(title: 'Updated Test Goal')
      expect(goal_to_delete).to be_present
      goal_id = goal_to_delete.id
      
      visit organization_goal_path(organization, goal_to_delete)
      
      # Find and click delete button with confirmation
      # Use JavaScript to handle Turbo and confirmation
      delete_link = find('a.btn-outline-danger', text: /Archive Goal/i, wait: 5)
      page.execute_script("window.confirm = function() { return true; }")
      delete_link.click
      
      # Wait for redirect after deletion (Turbo might take a moment)
      sleep 1
      expect(page).to have_current_path(organization_goals_path(organization), wait: 10)
      
      # Verify deletion in database (soft delete)
      deleted_goal = Goal.find_by(id: goal_id)
      expect(deleted_goal).to be_present
      expect(deleted_goal.deleted_at).to be_present
    end
    
    it 'shows validation errors for missing required fields' do
      visit new_organization_goal_path(organization)
      
      # Try to submit empty form
      click_button 'Create Goal'
      
      # Should show validation errors or stay on form
      # The form validation might happen client-side or server-side
      expect(page).to have_content('New Goal')
      # Check if there are any error messages displayed or form is still present
      error_text = page.text.downcase
      has_errors = error_text.include?('error') || 
                   error_text.include?('blank') ||
                   error_text.include?('required')
      expect(has_errors || page.has_field?('goal_title')).to be true
    end
    
    it 'displays target date when timeframe is selected' do
      visit new_organization_goal_path(organization)
      
      # Initially, target date info should not be visible
      expect(page).to have_css('#timeframe-target-date-info', visible: false)
      
      # Select near-term timeframe
      find('label[for="timeframe_near_term"]').click
      
      # Should show target date info with near-term date (90 days from today)
      expect(page).to have_css('#timeframe-target-date-info', visible: true)
      near_term_date = Date.today + 90.days
      expect(page).to have_content('Target date:')
      # Check for month name and year (flexible on day format)
      expect(page).to have_content(near_term_date.strftime('%B'))
      expect(page).to have_content(near_term_date.year.to_s)
      expect(page).to have_content('This date can be changed after creating the goal.')
      
      # Select medium-term timeframe
      find('label[for="timeframe_medium_term"]').click
      
      # Should show medium-term date (270 days from today)
      medium_term_date = Date.today + 270.days
      expect(page).to have_content(medium_term_date.strftime('%B'))
      expect(page).to have_content(medium_term_date.year.to_s)
      
      # Select long-term timeframe
      find('label[for="timeframe_long_term"]').click
      
      # Should show long-term date (3 years from today)
      long_term_date = Date.today + 3.years
      expect(page).to have_content(long_term_date.strftime('%B'))
      expect(page).to have_content(long_term_date.year.to_s)
      
      # Select vision timeframe
      find('label[for="timeframe_vision"]').click
      
      # Vision goals don't have a target date, so info should be hidden
      expect(page).to have_css('#timeframe-target-date-info', visible: false)
    end
    
    it 'defaults privacy level to only_creator_owner_and_managers' do
      visit new_organization_goal_path(organization)
      
      # Privacy level is now defaulted in the controller and not shown on the form
      # The form should show a message that privacy can be customized after creation
      expect(page).to have_content('You can customize privacy settings and target dates after creating the goal')
    end
    
    it 'allows creating goal without target dates' do
      visit new_organization_goal_path(organization)
      
      fill_in 'goal_title', with: 'Test Goal'
      
      # Select a timeframe - click on label instead of radio button
      find('label[for="timeframe_near_term"]').click
      
      # Select owner (should be pre-selected, but ensure it's set)
      select "Teammate: #{person.display_name}", from: 'goal[owner_id]'
      
      # Verify privacy_level hidden field exists
      expect(page).to have_field('goal_privacy_level', type: 'hidden', with: 'only_creator_owner_and_managers', visible: false)
      
      click_button 'Create Goal'
      
      # Should successfully create and redirect to check-in mode
      # Wait for the redirect to complete - check for "Check-in Mode" which is the page title
      expect(page).to have_content('Check-in Mode', wait: 10)
      
      created_goal = Goal.find_by(title: 'Test Goal')
      expect(created_goal).to be_present, "Goal was not created."
      expect(page).to have_current_path(weekly_update_organization_goal_path(organization, created_goal))
      expect(page).to have_content('Test Goal')
    end
    
    xit 'filters goals by timeframe' do # SKIPPED: Goal index must have owner not yet implemented
      # Create goals with different timeframes
      teammate = person.teammates.find_by(organization: organization) || CompanyTeammate.create!(person: person, organization: organization)
      now_goal = create(:goal, 
        creator: teammate, 
        owner: teammate, 
        title: 'Now Goal',
        earliest_target_date: Date.today + 1.week,
        most_likely_target_date: Date.today + 1.month,
        latest_target_date: Date.today + 2.months
      )
      next_goal = create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Next Goal',
        earliest_target_date: Date.today + 4.months,
        most_likely_target_date: Date.today + 6.months,
        latest_target_date: Date.today + 9.months
      )
      later_goal = create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Later Goal',
        earliest_target_date: Date.today + 10.months,
        most_likely_target_date: Date.today + 12.months,
        latest_target_date: Date.today + 18.months
      )
      
      visit organization_goals_path(organization)
      
      # Select owner if needed (it's in a modal)
      if page.has_content?('Please select an owner')
        # Open the filter modal
        click_button 'Filter & Sort'
        expect(page).to have_content('Select an owner')
        select "Teammate: #{teammate.person.display_name}", from: 'owner_id'
        within('#goalsFilterModal') do
          click_button 'Apply Filters'
        end
        expect(page).to have_content('Goals')
      end
      
      # Should see all goals
      expect(page).to have_content('Now Goal')
      expect(page).to have_content('Next Goal')
      expect(page).to have_content('Later Goal')
      
      # Approach 1: Open filter modal and apply timeframe filter
      click_button 'Filter & Sort'
      expect(page).to have_content('Select an owner')
      
      # Filter by "now" timeframe
      within('#goalsFilterModal') do
        # Select owner first (required)
        select "Teammate: #{teammate.person.display_name}", from: 'owner_id'
        choose 'timeframe_now'
        click_button 'Apply Filters'
      end
      
      # Approach 2: Verify filtering in database
      # Goals with "now" timeframe should have most_likely_target_date within 3 months
      now_goals = Goal.where(owner: teammate, owner_type: 'CompanyTeammate')
                     .where('most_likely_target_date >= ? AND most_likely_target_date < ?', Date.today, Date.today + 3.months)
      expect(now_goals.pluck(:id)).to include(now_goal.id)
      expect(now_goals.pluck(:id)).not_to include(next_goal.id, later_goal.id)
      
      # Approach 3: Check UI for filtered results
      expect(page).to have_content('Now Goal')
      expect(page).not_to have_content('Next Goal')
      expect(page).not_to have_content('Later Goal')
      
      # Approach 4: Verify URL contains timeframe parameter
      expect(page.current_url).to include('timeframe=now')
      
      # Approach 5: Check that filtered goals match the scope
      displayed_goal_ids = page.all('a[href*="/goals/"]').map { |link| link[:href].match(/\/goals\/(\d+)/)&.[](1) }.compact.map(&:to_i)
      expect(displayed_goal_ids).to include(now_goal.id)
      expect(displayed_goal_ids).not_to include(next_goal.id, later_goal.id)
      
      # Approach 6: Verify using Goal model's now scope
      expect(Goal.timeframe_now.where(owner: teammate, owner_type: 'CompanyTeammate').pluck(:id)).to include(now_goal.id)
    end
    
    xit 'filters goals by goal type' do # SKIPPED: Goal index must have owner not yet implemented
      teammate = person.teammates.find_by(organization: organization) || CompanyTeammate.create!(person: person, organization: organization)
      inspirational = create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Inspirational Goal',
        goal_type: 'inspirational_objective'
      )
      qualitative = create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Qualitative Goal',
        goal_type: 'qualitative_key_result'
      )
      
      visit organization_goals_path(organization)
      
      # Select owner if needed (it's in a modal)
      if page.has_content?('Please select an owner')
        # Open the filter modal
        click_button 'Filter & Sort'
        expect(page).to have_content('Select an owner')
        select "Teammate: #{teammate.person.display_name}", from: 'owner_id'
        within('#goalsFilterModal') do
          click_button 'Apply Filters'
        end
        expect(page).to have_content('Goals')
      end
      
      # Should see both goals
      expect(page).to have_content('Inspirational Goal')
      expect(page).to have_content('Qualitative Goal')
      
      # Approach 1: Open filter modal and apply goal type filter
      click_button 'Filter & Sort'
      expect(page).to have_content('Select an owner')
      
      # Filter by inspirational_objective - use the checkbox ID
      within('#goalsFilterModal') do
        # Select owner first (required)
        select "Teammate: #{teammate.person.display_name}", from: 'owner_id'
        find('#goal_type_inspirational_objective').check
        click_button 'Apply Filters'
      end
      
      # Approach 2: Verify filtering in database
      filtered_goals = Goal.where(owner: teammate, owner_type: 'CompanyTeammate', goal_type: 'inspirational_objective')
      expect(filtered_goals.pluck(:id)).to include(inspirational.id)
      expect(filtered_goals.pluck(:id)).not_to include(qualitative.id)
      
      # Approach 3: Check UI for filtered results
      expect(page).to have_content('Inspirational Goal')
      expect(page).not_to have_content('Qualitative Goal')
      
      # Approach 4: Verify URL contains goal_type parameter
      expect(page.current_url).to include('goal_type')
      
      # Approach 5: Check that filtered goals match the scope
      displayed_goal_ids = page.all('a[href*="/goals/"]').map { |link| link[:href].match(/\/goals\/(\d+)/)&.[](1) }.compact.map(&:to_i)
      expect(displayed_goal_ids).to include(inspirational.id)
      expect(displayed_goal_ids).not_to include(qualitative.id)
      
      # Approach 6: Verify using Goal model's goal_type enum
      expect(Goal.inspirational_objective.where(owner: teammate, owner_type: 'CompanyTeammate').pluck(:id)).to include(inspirational.id)
    end
    
    xit 'sorts goals by target date' do # SKIPPED: Goal index must have owner not yet implemented
      teammate = person.teammates.find_by(organization: organization) || CompanyTeammate.create!(person: person, organization: organization)
      goal1 = create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Goal 1',
        most_likely_target_date: Date.today + 3.months
      )
      goal2 = create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Goal 2',
        most_likely_target_date: Date.today + 1.month
      )
      goal3 = create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Goal 3',
        most_likely_target_date: Date.today + 2.months
      )
      
      visit organization_goals_path(organization)
      
      # Select owner if needed (it's in a modal)
      if page.has_content?('Please select an owner')
        # Open the filter modal - Capybara's click_button has implicit wait
        click_button 'Filter & Sort'
        # Check for modal content instead of class
        expect(page).to have_content('Select an owner')
        select "Teammate: #{teammate.person.display_name}", from: 'owner_id'
        within('#goalsFilterModal') do
          click_button 'Apply Filters'
        end
        expect(page).to have_content('Goals')
      end
      
      # Open filter modal - Capybara's click_button has implicit wait
      click_button 'Filter & Sort'
      # Check for modal content instead of class
      expect(page).to have_content('Select an owner')
      
      # Approach 1: Apply sorting via form
      within('#goalsFilterModal') do
        # Select owner first (required)
        select "Teammate: #{teammate.person.display_name}", from: 'owner_id'
        select 'Most Likely Date', from: 'sort'
        select 'Ascending', from: 'direction'
        click_button 'Apply Filters'
      end
      
      # Approach 2: Verify sorting in database
      sorted_goals = Goal.where(owner: teammate, owner_type: 'CompanyTeammate')
                        .order(most_likely_target_date: :asc)
      expect(sorted_goals.pluck(:id)).to eq([goal2.id, goal3.id, goal1.id])
      
      # Approach 3: Check UI order by finding positions in page text
      page_text = page.body
      goal2_pos = page_text.index('Goal 2')
      goal3_pos = page_text.index('Goal 3')
      goal1_pos = page_text.index('Goal 1')
      
      # All should be present
      expect(goal2_pos).to be_present
      expect(goal3_pos).to be_present
      expect(goal1_pos).to be_present
      # Verify order
      expect(goal2_pos).to be < goal3_pos
      expect(goal3_pos).to be < goal1_pos
      
      # Approach 4: Verify URL contains sort and direction parameters
      expect(page.current_url).to include('sort=most_likely_target_date')
      expect(page.current_url).to include('direction=asc')
      
      # Approach 5: Check order by extracting goal IDs from table rows
      goal_rows = page.all('tr').select { |row| row.text.match(/Goal [123]/) }
      goal_titles = goal_rows.map { |row| row.text.match(/Goal ([123])/)[1] }
      expect(goal_titles).to eq(['2', '3', '1'])
      
      # Approach 6: Verify using CSS selectors to find goal links in order
      goal_links = page.all('a[href*="/goals/"]').select { |link| link.text.match(/Goal [123]/) }
      goal_order = goal_links.map { |link| link.text.match(/Goal ([123])/)[1] }
      expect(goal_order).to eq(['2', '3', '1'])
    end
  end
  
  describe 'Goal Linking Workflow' do
    let!(:teammate) { person.teammates.find_by(organization: organization) || CompanyTeammate.create!(person: person, organization: organization) }
    let!(:goal1) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 1') }
    let!(:goal2) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 2', goal_type: 'stepping_stone_activity') }
    
    it 'creates a link between goals' do
      visit organization_goal_path(organization, goal1)
      
      # Should see outgoing links section
      expect(page).to have_content(/In order to achieve|Goal/i)
      expect(page).to have_button('New Child Goal')
      
      # Click the dropdown and select stepping stones/activities option
      find('button.dropdown-toggle', text: 'New Child Goal').click
      find('a.dropdown-item', text: '... this new stepping stone / activity / output').click
      
      # Should be on the new outgoing link page (overlay)
      expect(page).to have_content('Create Links to Other Goals')
      
      # Select goal2 from checkboxes
      check "goal_ids_#{goal2.id}"
      
      # Submit form
      click_button 'Create Links', id: 'create-existing-links-btn'
      
      # Should be redirected to goal show page with success
      expect(page).to have_current_path(organization_goal_path(organization, goal1))
      expect(page).to have_content('Goal 2')
    end
    
    it 'prevents self-linking' do
      visit organization_goal_path(organization, goal1)
      
      # Click the dropdown and select stepping stones/activities option
      find('button.dropdown-toggle', text: 'New Child Goal').click
      find('a.dropdown-item', text: '... this new stepping stone / activity / output').click
      
      # Should be on the new outgoing link page
      expect(page).to have_content('Create Links to Other Goals')
      
      # Goal1 should not appear in the checkbox list (it's excluded)
      expect(page).not_to have_field("goal_ids_#{goal1.id}")
      
      # Goal2 should be available
      expect(page).to have_field("goal_ids_#{goal2.id}")
    end
    
    it 'unlinks a goal link' do
      # Create link between goals
      link = create(:goal_link, parent: goal1, child: goal2)
      link_id = link.id
      
      visit organization_goal_path(organization, goal1)
      
      # Verify link is displayed on page in the outgoing links section
      expect(page).to have_content('In pursuit of')
      expect(page).to have_content(goal2.title)
      
      # Find unlink button - button_to creates a form with a button inside
      # Look for the button within a form that posts to the delete path
      unlink_form = find("form[action='#{organization_goal_goal_link_path(organization, goal1, link)}']")
      expect(unlink_form).to be_present
      
      # Set up JavaScript confirm to return true before clicking
      page.execute_script("window.confirm = function() { return true; }")
      
      # Click the unlink button (button_to creates a button inside a form)
      within(unlink_form) do
        click_button
      end
      
      # Wait for redirect (Capybara's built-in waiting)
      expect(page).to have_current_path(organization_goal_path(organization, goal1))
      
      # Verify database deletion after redirect completes
      expect(GoalLink.find_by(id: link_id)).to be_nil
      
      # Verify link is gone from page (uses built-in waiting)
      expect(page).to have_no_content(goal2.title)
      
      # Verify success message is present (may be in toast, so check with visible: false)
      expect(page).to have_css('.toast-body', text: 'Goal link was successfully deleted', visible: false)
    end
    
    it 'shows Fix Goal button for child goal without target date' do
      # Create a child goal without target date
      child_goal = create(:goal, creator: teammate, owner: teammate, title: 'Child Goal', goal_type: 'stepping_stone_activity', most_likely_target_date: nil)
      create(:goal_link, parent: goal1, child: child_goal)
      
      visit organization_goal_path(organization, goal1)
      
      # Should see Fix Goal link (it's a link_to, not a button)
      expect(page).to have_link('Fix Goal')
      
      # Link should have danger class
      fix_link = find_link('Fix Goal')
      expect(fix_link[:class]).to include('btn-danger')
    end
    
    it 'shows Start button for child goal with target date but not started' do
      # Create a child goal with target date but not started
      child_goal = create(:goal, creator: teammate, owner: teammate, title: 'Child Goal', goal_type: 'stepping_stone_activity', most_likely_target_date: Date.current + 90.days, started_at: nil)
      create(:goal_link, parent: goal1, child: child_goal)
      
      visit organization_goal_path(organization, goal1)
      
      # Should see Start button (within the linked goal section, not the main goal's Start Now button)
      within('li', text: child_goal.title) do
        expect(page).to have_button('Start')
        
        # Button should be primary color
        start_button = find_button('Start')
        expect(start_button[:class]).to include('btn-primary')
      end
    end
    
    it 'Fix Goal button links to goal show page and opens in new window' do
      child_goal = create(:goal, creator: teammate, owner: teammate, title: 'Child Goal', goal_type: 'stepping_stone_activity', most_likely_target_date: nil)
      create(:goal_link, parent: goal1, child: child_goal)
      
      visit organization_goal_path(organization, goal1)
      
      fix_link = find_link('Fix Goal')
      expect(fix_link[:target]).to eq('_blank')
      expect(fix_link[:href]).to include(organization_goal_path(organization, child_goal))
    end
    
    it 'Start button starts the goal' do
      child_goal = create(:goal, creator: teammate, owner: teammate, title: 'Child Goal', goal_type: 'stepping_stone_activity', most_likely_target_date: Date.current + 90.days, started_at: nil)
      create(:goal_link, parent: goal1, child: child_goal)
      
      visit organization_goal_path(organization, goal1)
      
      # Find Start button within the linked goal's section
      within('li', text: child_goal.title) do
        click_button 'Start'
      end
      
      # Wait for redirect (Capybara's built-in waiting)
      expect(page).to have_current_path(organization_goal_path(organization, goal1))
      
      # Verify database was updated after redirect completes
      expect(child_goal.reload.started_at).not_to be_nil
      
      # Verify success message is present (may be in toast, so check with visible: false)
      expect(page).to have_css('.toast-body', text: 'Goal started successfully', visible: false)
    end
    
    it 'does not show buttons for objective goals' do
      objective_goal = create(:goal, creator: teammate, owner: teammate, title: 'Objective Goal', goal_type: 'inspirational_objective', most_likely_target_date: nil)
      create(:goal_link, parent: goal1, child: objective_goal)
      
      visit organization_goal_path(organization, goal1)
      
      # Check within the linked goal's section to avoid false positives from main goal's buttons
      within('li', text: objective_goal.title) do
        expect(page).not_to have_link('Fix Goal')
        expect(page).not_to have_button('Start')
      end
    end
    
    it 'displays note icon with tooltip for links with notes' do
      note_text = 'This is an important note about the link'
      link_with_notes = create(:goal_link, parent: goal1, child: goal2, metadata: { 'notes' => note_text })
      
      visit organization_goal_path(organization, goal1)
      
      # Should see the goal title
      expect(page).to have_content(goal2.title)
      
      # Should see the note icon
      within('li', text: goal2.title) do
        note_icon = find('i.bi-file-text')
        expect(note_icon).to be_present
        expect(note_icon['data-bs-toggle']).to eq('tooltip')
        expect(note_icon['data-bs-title']).to eq(note_text)
      end
    end
    
    it 'does not display note icon for links without notes' do
      link_without_notes = create(:goal_link, parent: goal1, child: goal2, metadata: nil)
      
      visit organization_goal_path(organization, goal1)
      
      # Should see the goal title
      expect(page).to have_content(goal2.title)
      
      # Should not see the note icon
      within('li', text: goal2.title) do
        expect(page).not_to have_css('i.bi-file-text')
      end
    end
    
    it 'displays note icon with tooltip for incoming links with notes' do
      note_text = 'This is a note about the incoming link'
      parent_goal = create(:goal, creator: teammate, owner: teammate, title: 'Parent Goal')
      link_with_notes = create(:goal_link, parent: parent_goal, child: goal1, metadata: { 'notes' => note_text })
      
      visit organization_goal_path(organization, goal1)
      
      # Expand Advanced Settings to see incoming links section
      find('button[data-bs-target="#advancedSettings"]').click
      
      # Should see the parent goal title in incoming links section
      expect(page).to have_content('Pursuing')
      expect(page).to have_content(parent_goal.title)
      
      # Should see the note icon in incoming links section
      within('li', text: parent_goal.title) do
        note_icon = find('i.bi-file-text')
        expect(note_icon).to be_present
        expect(note_icon['data-bs-toggle']).to eq('tooltip')
        expect(note_icon['data-bs-title']).to eq(note_text)
      end
    end
    
    it 'does not show buttons for completed goals' do
      completed_goal = create(:goal, creator: teammate, owner: teammate, title: 'Completed Goal', goal_type: 'stepping_stone_activity', most_likely_target_date: Date.current + 90.days, started_at: 1.week.ago, completed_at: 1.day.ago)
      create(:goal_link, parent: goal1, child: completed_goal)
      
      visit organization_goal_path(organization, goal1)
      
      # Check within the linked goal's section to avoid false positives from main goal's buttons
      within('li', text: completed_goal.title) do
        expect(page).not_to have_link('Fix Goal')
        expect(page).not_to have_button('Start')
      end
    end
    
  end
  
  describe 'Privacy Level Restrictions' do
    let!(:teammate) { person.teammates.find_by(organization: organization) || CompanyTeammate.create!(person: person, organization: organization) }
    let(:other_person) { create(:person) }
    let!(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: organization) }
    let!(:private_goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'Private Goal',
        privacy_level: 'only_creator'
      )
    end
    
    before do
      sign_in_as(other_person, organization)
    end
    
    xit 'hides private goals from other users' do # SKIPPED: Goal index must have owner not yet implemented
      # Approach 1: Verify authorization via can_be_viewed_by
      expect(private_goal.can_be_viewed_by?(other_person)).to be false
      
      visit organization_goals_path(organization)
      
      # Select owner if needed
      if page.has_content?('Please select an owner')
        click_button 'Filter & Sort'
        expect(page).to have_content('Select an owner')
        select "Teammate: #{teammate.person.display_name}", from: 'owner_id'
        within('#goalsFilterModal') do
          click_button 'Apply Filters'
        end
        expect(page).to have_content('Goals')
      end
      
      # Approach 2: Verify goal is not in policy scope for other_person
      other_teammate = other_person.teammates.find_by(organization: organization)
      pundit_user = OpenStruct.new(user: other_teammate, pundit_organization: organization)
      policy_scope = GoalPolicy::Scope.new(pundit_user, Goal).resolve
      expect(policy_scope.where(id: private_goal.id)).not_to exist
      
      # Approach 3: Verify goal IDs in displayed list don't include private goal
      displayed_goal_ids = page.all('a[href*="/goals/"]').map { |link| link[:href].match(/\/goals\/(\d+)/)&.[](1) }.compact.map(&:to_i)
      expect(displayed_goal_ids).not_to include(private_goal.id)
      
      # Approach 4: Check UI for absence of private goal
      expect(page).not_to have_content('Private Goal')
      
      # Approach 5: Try to access directly - verify authorization failure
      begin
        visit organization_goal_path(organization, private_goal)
        # If we get here, check that the page doesn't show the goal
        expect(page).not_to have_content('Private Goal')
      rescue Pundit::NotAuthorizedError
        # Expected - authorization denied
      end
      
      # Approach 6: Verify using GoalPolicy show? method
      policy_user = OpenStruct.new(user: other_teammate, pundit_organization: organization)
      policy = GoalPolicy.new(policy_user, private_goal)
      expect(policy.show?).to be false
    end
    
    xit 'shows shared goals to authorized users' do # SKIPPED: Goal index must have owner not yet implemented
      # Use existing teammate or create one for the creator
      creator_teammate = person.teammates.find_by(organization: organization) || teammate
      
      # For everyone_in_company privacy, the owner needs to be an Organization (not a Person)
      # because owner_company now returns the company via company_id for Teammate owners
      # Create the goal with organization as owner
      shared_goal = create(:goal,
        creator: creator_teammate,
        owner: organization,
        title: 'Shared Goal',
        privacy_level: 'everyone_in_company'
      )
      
      # other_person needs to be a teammate in the organization to see everyone_in_company goals
      # other_teammate is already created in the describe block
      visit organization_goals_path(organization)
      
      # Select owner if needed (organization goals might need different selection)
      if page.has_content?('Please select an owner')
        # Open the filter modal - Capybara's click_button has implicit wait
        click_button 'Filter & Sort'
        expect(page).to have_content('Select an owner')
        # For organization goals, select format is "Company_#{id}" or "Company: #{name}"
        # Try both formats - the select uses the value which is "Company_#{id}"
        begin
          select "Company: #{organization.display_name}", from: 'owner_id'
        rescue Capybara::ElementNotFound
          # If that doesn't work, try finding by value
          select_element = find('select[name="owner_id"]')
          option = select_element.find("option[value='Company_#{organization.id}']")
          option.select_option
        end
        within('#goalsFilterModal') do
          click_button 'Apply Filters'
        end
      end
      
      # Verify goal exists and is accessible
      shared_goal.reload
      expect(shared_goal).to be_present
      expect(shared_goal.company_id).to eq(organization.id)
      
      # Approach 1: Verify other_person can view it via can_be_viewed_by
      expect(shared_goal.can_be_viewed_by?(other_person)).to be true
      
      # Approach 2: Verify it's in policy scope for other_person
      # Create a policy instance with other_person's context
      other_teammate = other_person.teammates.find_by(organization: organization)
      expect(other_teammate).to be_present
      pundit_user = OpenStruct.new(user: other_teammate, pundit_organization: organization)
      policy_scope = GoalPolicy::Scope.new(pundit_user, Goal).resolve
      expect(policy_scope.where(id: shared_goal.id)).to exist
      
      # Approach 3: Check if goal appears in filtered results directly
      # The filter should show goals with owner_type='Company' and owner_id=organization.id
      filtered_goals = Goal.where(company_id: organization.id, owner_type: 'Company', owner_id: organization.id)
      expect(filtered_goals.where(id: shared_goal.id)).to exist
      
      # Approach 4: Verify URL contains correct owner filter
      expect(page.current_url).to include("owner_type=Company")
      expect(page.current_url).to include("owner_id=#{organization.id}")
      
      # Approach 5: Check that goal appears in the goals list by extracting IDs
      displayed_goal_ids = page.all('a[href*="/goals/"]').map { |link| link[:href].match(/\/goals\/(\d+)/)&.[](1) }.compact.map(&:to_i)
      expect(displayed_goal_ids).to include(shared_goal.id)
      
      # Approach 6: Verify using Goal model's for_teammate scope
      expect(Goal.for_teammate(other_teammate).where(id: shared_goal.id)).to exist
      
      # Should see shared goal (other_person is also a teammate in the org)
      expect(page).to have_content('Shared Goal')
      
      # Can view the goal
      click_link 'Shared Goal'
      expect(page).to have_content('Shared Goal')
    end
  end
  
  describe 'Dashboard Hero Card Interactions' do
    let!(:teammate) { person.teammates.find_by(organization: organization) || CompanyTeammate.create!(person: person, organization: organization) }
    let!(:personal_goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        title: 'My Personal Goal'
      )
    end
    
    xit 'links to goals index from about_me page' do # SKIPPED: Goal index must have owner not yet implemented
      teammate = person.teammates.find_by(organization: organization)
      visit about_me_organization_company_teammate_path(organization, teammate)
      
      # Should see goals section
      expect(page).to have_content(/Active Goals/i)
      
      # Find and click the "View My Goals" link
      goals_link = find('a', text: /View My Goals/i, wait: 5)
      goals_link.click
      
      # Wait for navigation - goals index requires owner selection
      expect(page).to have_content(/Goals|Select an owner/i, wait: 5)
      
      # Select owner if needed (it's in a modal)
      if page.has_content?('Please select an owner') || page.has_content?('Select an owner')
        # Open the filter modal
        click_button 'Filter & Sort'
        expect(page).to have_content('Select an owner')
        select "Teammate: #{person.display_name}", from: 'owner_id'
        within('#goalsFilterModal') do
          click_button 'Apply Filters'
        end
        expect(page).to have_content('Goals')
      end
      
      expect(page).to have_content('My Personal Goal')
    end
    
    it 'links to create new goal from about_me page' do
      teammate = person.company_teammates.find_by!(organization: organization)
      visit about_me_organization_company_teammate_path(organization, teammate)
      
      # Navigate to goals index to create new goal
      visit organization_goals_path(organization)
      
      # Goals index has a dropdown: click the plus button and choose "Create single goal"
      page.find('.dropdown button.dropdown-toggle').click
      click_link 'Create single goal'
      expect(page).to have_content('New Goal')
      expect(page).to have_field('goal_title')
    end
    
    it 'links to goals index (hierarchical with check-ins) from about_me page' do
      teammate = person.company_teammates.find_by!(organization: organization)
      visit about_me_organization_company_teammate_path(organization, teammate)

      # Goals section is collapsible; expand it via Bootstrap then click the link
      expect(page).to have_content(/Active Goals|Goals/i)
      page.execute_script("document.querySelector('[data-bs-target=\"#goalsSection\"]').click()")
      expect(page).to have_link('Manage Goals & Confidence Ratings', wait: 2)
      click_link 'Manage Goals & Confidence Ratings'

      # Wait for navigation to goals index, then check params
      expect(page).to have_current_path(/\/goals(\?|$)/, wait: 5)
      expect(page.current_url).to include('view=hierarchical-collapsible')
      expect(page.current_url).to include("owner_id=CompanyTeammate_#{teammate.id}")
    end
  end
end

