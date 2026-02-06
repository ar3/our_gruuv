require 'rails_helper'

RSpec.describe 'Goal Link Creation', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.create!(person: person, organization: organization) }
  let(:goal1) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 1', privacy_level: 'everyone_in_company', goal_type: 'stepping_stone_activity') }
  let(:goal2) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 2', privacy_level: 'everyone_in_company', goal_type: 'stepping_stone_activity') }
  let(:goal3) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 3', privacy_level: 'everyone_in_company', goal_type: 'stepping_stone_activity') }
  
  # Create records in before block to ensure they're created AFTER DatabaseCleaner.clean runs
  # This prevents test isolation issues where stale data from previous tests interferes
  before do
    # Clear any existing ApplicationController stubs that might be persisting from other specs
    # This is a defensive measure to prevent test isolation issues
    # Only reset if proxy exists - don't remove stubs we're about to set up
    begin
      proxy = RSpec::Mocks.space.proxy_for(ApplicationController)
      proxy.reset if proxy && proxy.instance_variable_get(:@method_doubles)&.any?
    rescue => e
      # If reset fails, continue - we'll set up fresh stubs anyway
    end
    
    # Create records after database is cleaned
    # Force evaluation of let blocks to create records
    teammate
    goal1
    goal2
    goal3
    
    # Verify relationships are correct (defensive check)
    expect(teammate.person).to eq(person)
    expect(teammate.organization).to eq(organization)
    
    # Set up fresh stubs for this test (will override any existing stubs)
    # Use call_original: false to ensure stubs take precedence
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(teammate)
  end
  
  # Clear stubs after each test to prevent them from leaking to other specs
  after do
    begin
      # Reset the proxy to clear stubs after test completes
      proxy = RSpec::Mocks.space.proxy_for(ApplicationController)
      proxy.reset if proxy
    rescue => e
      # If cleanup fails, it's okay - RSpec should handle it
    end
  end
  
  describe 'navigating to overlay pages' do
    it 'navigates to new_outgoing_link page from show page' do
      visit organization_goal_path(organization, goal1)
      
      expect(page).to have_content('In order to achieve')
      expect(page).to have_button('New Child Goal')
      
      # Visit the URL directly to verify the route works
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      expect(page.current_path).to include('new_outgoing_link')
      expect(page).to have_content('Create Links to Other Goals')
      expect(page).to have_link('Goal')
    end
    
    it 'shows Add Child Goal button even when there are existing child goals' do
      # Create a child goal
      create(:goal_link, parent: goal1, child: goal2)
      
      visit organization_goal_path(organization, goal1)
      
      # Should show the Add Child Goal button above the list
      expect(page).to have_button('New Child Goal')
      # Should also show the existing child goal
      expect(page).to have_content('Goal 2')
    end
    
    it 'navigates to new_incoming_link page from show page' do
      visit organization_goal_path(organization, goal1)
      
      # Visit the URL directly to verify the route works  
      visit new_incoming_link_organization_goal_goal_links_path(organization, goal1)
      
      expect(page.current_path).to include('new_incoming_link')
      expect(page).to have_content('Create Links from Other Goals')
      expect(page).to have_link('Goal')
    end
    
    it 'passes return_url and return_text correctly' do
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1, return_url: organization_goal_path(organization, goal1), return_text: 'Goal')
      
      expect(page).to have_content('Create Links to Other Goals')
      expect(page).to have_link('Goal', href: organization_goal_path(organization, goal1))
    end
  end
  
  describe 'selecting existing goals (outgoing links)' do
    it 'displays list of available goals as checkboxes' do
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      expect(page).to have_content('Existing Goals')
      expect(page).to have_unchecked_field('goal_ids[]', with: goal2.id.to_s)
      expect(page).to have_unchecked_field('goal_ids[]', with: goal3.id.to_s)
      expect(page).to have_content('Goal 2')
      expect(page).to have_content('Goal 3')
    end
    
    it 'excludes current goal from list' do
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      # Check that goal1 checkbox is not in the form
      expect(page).not_to have_field("goal_ids_#{goal1.id}")
      
      # Check that goal2 and goal3 are in the list
      expect(page).to have_field("goal_ids_#{goal2.id}")
      expect(page).to have_field("goal_ids_#{goal3.id}")
    end
    
    it 'creates a link when selecting a single existing goal' do
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      check "goal_ids_#{goal2.id}"
      
      click_button 'Create Links', id: 'create-existing-links-btn'
      
      # Check for toast element in DOM (may not be visible immediately due to JS)
      expect(page).to have_css('.toast', text: 'Goal link was successfully created', visible: :hidden)
      expect(page).to have_current_path(organization_goal_path(organization, goal1))
      expect(page).to have_content('Goal 2')
      
      link = GoalLink.find_by(parent: goal1, child: goal2)
      expect(link).to be_present
    end
    
    it 'creates multiple links when selecting multiple existing goals' do
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      check "goal_ids_#{goal2.id}"
      check "goal_ids_#{goal3.id}"
      
      click_button 'Create Links', id: 'create-existing-links-btn'
      
      # Check for toast element in DOM (may not be visible immediately due to JS)
      expect(page).to have_css('.toast', text: 'Goal link was successfully created', visible: :hidden)
      expect(page).to have_current_path(organization_goal_path(organization, goal1))
      
      link2 = GoalLink.find_by(parent: goal1, child: goal2)
      link3 = GoalLink.find_by(parent: goal1, child: goal3)
      expect(link2).to be_present
      expect(link3).to be_present
    end
    
    it 'shows validation error when no goals selected and no bulk titles provided' do
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)

      click_button 'Create Links', id: 'create-existing-links-btn'

      expect(page).to have_content(/error|required|select/i)
      expected_path = new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      expect(URI.parse(page.current_url).path).to eq(expected_path)
    end
    
    it 'prevents self-linking' do
      # This test might not be needed since current goal is excluded from list
      # But we should test that if somehow self-linking is attempted, it's prevented
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      # Current goal shouldn't be in the list
      expect(page).not_to have_field('goal_ids[]', with: goal1.id.to_s)
    end
    
    it 'prevents duplicate links' do
      # Create existing link
      create(:goal_link, parent: goal1, child: goal2)
      
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      # Goal2 should be checked and disabled (already linked)
      goal2_checkbox = find("input#goal_ids_#{goal2.id}")
      expect(goal2_checkbox).to be_disabled
      expect(goal2_checkbox).to be_checked
      
      expect(page).to have_content('Already Linked')
      
      # Should only have one link
      expect(GoalLink.where(parent: goal1, child: goal2).count).to eq(1)
    end

    it 'does not show team/department/company goals when parent goal is teammate-owned' do
      org_goal = create(:goal, creator: teammate, owner: organization, title: 'Company-wide initiative', goal_type: 'stepping_stone_activity', company: organization, privacy_level: 'everyone_in_company')
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1, goal_type: 'stepping_stone_activity')

      expect(page).to have_content('Existing Goals')
      expect(page).not_to have_content('Company-wide initiative')
      expect(page).to have_content('Goal 2')
    end
  end
  
  describe 'selecting existing goals (incoming links)' do
    it 'displays list of available goals as checkboxes' do
      visit new_incoming_link_organization_goal_goal_links_path(organization, goal1)
      
      expect(page).to have_content('Existing Goals')
      expect(page).to have_unchecked_field('goal_ids[]', with: goal2.id.to_s)
      expect(page).to have_unchecked_field('goal_ids[]', with: goal3.id.to_s)
    end
    
    it 'creates an incoming link when selecting an existing goal' do
      visit new_incoming_link_organization_goal_goal_links_path(organization, goal1)
      
      check "goal_ids_#{goal2.id}"
      click_button 'Create Links', id: 'create-existing-links-btn'
      
      # Check for toast element in DOM (may not be visible immediately due to JS)
      expect(page).to have_css('.toast', text: 'Goal link was successfully created', visible: :hidden)
      expect(page).to have_current_path(organization_goal_path(organization, goal1))
      
      link = GoalLink.find_by(parent: goal2, child: goal1)
      expect(link).to be_present
    end
  end
  
  describe 'creating new goals via bulk creation (outgoing links)' do
    it 'accepts multiple goal titles in textarea (one per line)' do
      unique_suffix = SecureRandom.hex(4)
      titles = ["Bulk Goal 1 #{unique_suffix}", "Bulk Goal 2 #{unique_suffix}", "Bulk Goal 3 #{unique_suffix}"]
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      fill_in 'bulk_goal_titles', with: titles.join("\n")
      click_button 'Create Links', id: 'create-bulk-links-btn'
      
      # Wait for redirect and success message before checking database
      expect(page).to have_current_path(organization_goal_path(organization, goal1), wait: 5)
      expect(page).to have_css('.toast', text: 'Goal link was successfully created', visible: :hidden, wait: 5)
      
      created_goals = Goal.where(title: titles)
      expect(created_goals.count).to eq(3)
    end
    
    it 'creates new goals as quantitative_key_result for outgoing links' do
      unique_title = "Bulk Key Result #{SecureRandom.hex(4)}"
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1, goal_type: 'quantitative_key_result')
      
      fill_in 'bulk_goal_titles', with: unique_title
      click_button 'Create Links', id: 'create-bulk-links-btn'
      
      # Wait for redirect and success message before checking database
      expect(page).to have_current_path(organization_goal_path(organization, goal1), wait: 5)
      expect(page).to have_css('.toast', text: 'Goal link was successfully created', visible: :hidden, wait: 5)
      
      created_goal = Goal.find_by(title: unique_title)
      expect(created_goal).to be_present
      expect(created_goal.goal_type).to eq('quantitative_key_result')
    end
    
    it 'creates new goals matching owner and privacy_level of linking goal' do
      unique_title = "Bulk Goal #{SecureRandom.hex(4)}"
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      fill_in 'bulk_goal_titles', with: unique_title
      click_button 'Create Links', id: 'create-bulk-links-btn'
      
      # Wait for redirect and success message before checking database
      expect(page).to have_current_path(organization_goal_path(organization, goal1), wait: 5)
      expect(page).to have_css('.toast', text: 'Goal link was successfully created', visible: :hidden, wait: 5)
      
      created_goal = Goal.find_by(title: unique_title)
      expect(created_goal).to be_present
      expect(created_goal.owner).to eq(goal1.owner)
      expect(created_goal.privacy_level).to eq(goal1.privacy_level)
    end
    
    it 'creates new goals with no target dates' do
      # Set goal1 to have no target date so created goals also have no target date
      goal1.update!(most_likely_target_date: nil, earliest_target_date: nil, latest_target_date: nil)
      
      unique_title = "Bulk Goal No Dates #{SecureRandom.hex(4)}"
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1, goal_type: 'inspirational_objective')
      
      fill_in 'bulk_goal_titles', with: unique_title
      click_button 'Create Links', id: 'create-bulk-links-btn'
      
      # Wait for redirect and success message before checking database
      expect(page).to have_current_path(organization_goal_path(organization, goal1), wait: 5)
      expect(page).to have_css('.toast', text: 'Goal link was successfully created', visible: :hidden, wait: 5)
      
      created_goal = Goal.find_by(title: unique_title)
      expect(created_goal).to be_present
      # Inspirational objectives don't get target dates set
      expect(created_goal.goal_type).to eq('inspirational_objective')
      expect(created_goal.earliest_target_date).to be_nil
      expect(created_goal.most_likely_target_date).to be_nil
      expect(created_goal.latest_target_date).to be_nil
    end
    
    it 'saves metadata notes for bulk created goals' do
      unique_title = "Bulk Goal With Notes #{SecureRandom.hex(4)}"
      note_text = "This is a test note for bulk creation"
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      fill_in 'bulk_goal_titles', with: unique_title
      fill_in 'metadata_notes', with: note_text
      click_button 'Create Links', id: 'create-bulk-links-btn'
      
      # Wait for redirect and success message before checking database
      expect(page).to have_current_path(organization_goal_path(organization, goal1), wait: 5)
      expect(page).to have_css('.toast', text: 'Goal link was successfully created', visible: :hidden, wait: 5)
      
      created_goal = Goal.find_by(title: unique_title)
      expect(created_goal).to be_present
      
      # Check that the link has metadata
      link = GoalLink.find_by(parent: goal1, child: created_goal)
      expect(link).to be_present
      expect(link.metadata).to eq({ 'notes' => note_text })
      
      # Verify note icon appears on the page
      expect(page).to have_css('i.bi-file-text[data-bs-toggle="tooltip"]')
      note_icon = find('i.bi-file-text[data-bs-toggle="tooltip"]')
      expect(note_icon['data-bs-title']).to eq(note_text)
    end
    
    
    it 'automatically links new goals to current goal' do
      unique_title = "Bulk Goal Linked #{SecureRandom.hex(4)}"
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      fill_in 'bulk_goal_titles', with: unique_title
      click_button 'Create Links', id: 'create-bulk-links-btn'
      
      # Wait for redirect and success message before checking database
      expect(page).to have_current_path(organization_goal_path(organization, goal1), wait: 5)
      expect(page).to have_css('.toast', text: 'Goal link was successfully created', visible: :hidden, wait: 5)
      
      created_goal = Goal.find_by(title: unique_title)
      expect(created_goal).to be_present
      link = GoalLink.find_by(parent: goal1, child: created_goal)
      expect(link).to be_present
    end
    
    it 'shows validation error when bulk titles are blank' do
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      fill_in 'bulk_goal_titles', with: ""
      click_button 'Create Links', id: 'create-bulk-links-btn'
      
      expect(page).to have_css('.toast, .alert', text: /select at least one|provide at least one/i, visible: :hidden)
      expect(page.current_path).to include('new_outgoing_link')
    end
    
  end
  
  describe 'creating new goals via bulk creation (incoming links)' do
    it 'creates new goals as inspirational_objective for incoming links' do
      unique_title = "Bulk Objective #{SecureRandom.hex(4)}"
      visit new_incoming_link_organization_goal_goal_links_path(organization, goal1)
      
      fill_in 'bulk_goal_titles', with: unique_title
      click_button 'Create Links', id: 'create-existing-links-btn'
      
      # Wait for redirect and success message before checking database
      expect(page).to have_current_path(organization_goal_path(organization, goal1), wait: 5)
      expect(page).to have_css('.toast', text: 'Goal link was successfully created', visible: :hidden, wait: 5)
      
      created_goal = Goal.find_by(title: unique_title)
      expect(created_goal).to be_present
      expect(created_goal.goal_type).to eq('inspirational_objective')
    end
    
    it 'creates incoming links correctly for bulk goals' do
      unique_title = "Bulk Objective Incoming #{SecureRandom.hex(4)}"
      visit new_incoming_link_organization_goal_goal_links_path(organization, goal1)
      
      fill_in 'bulk_goal_titles', with: unique_title
      click_button 'Create Links', id: 'create-existing-links-btn'
      
      # Wait for redirect and success message before checking database
      expect(page).to have_current_path(organization_goal_path(organization, goal1), wait: 5)
      expect(page).to have_css('.toast', text: 'Goal link was successfully created', visible: :hidden, wait: 5)
      
      created_goal = Goal.find_by(title: unique_title)
      expect(created_goal).to be_present
      link = GoalLink.find_by(parent: created_goal, child: goal1)
      expect(link).to be_present
    end
  end
  
  describe 'combining existing + bulk creation' do
    it 'allows selecting existing goals AND entering bulk titles in one submission' do
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      check "goal_ids_#{goal2.id}"
      fill_in 'bulk_goal_titles', with: "Bulk Goal"
      click_button 'Create Links', id: 'create-existing-links-btn'
      
      # Check for toast element in DOM (may not be visible immediately due to JS)
      expect(page).to have_css('.toast', text: 'Goal link was successfully created', visible: :hidden)
      
      # Check existing link was created
      existing_link = GoalLink.find_by(parent: goal1, child: goal2)
      expect(existing_link).to be_present
      
      # Check new goal was created and linked
      bulk_goal = Goal.find_by(title: 'Bulk Goal')
      expect(bulk_goal).to be_present
      bulk_link = GoalLink.find_by(parent: goal1, child: bulk_goal)
      expect(bulk_link).to be_present
    end
  end
  
  describe 'error handling' do
    it 'displays validation errors on overlay page' do
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      # Try to submit without selecting anything
      click_button 'Create Links', id: 'create-existing-links-btn'
      
      expect(page).to have_css('.toast, .alert', text: /select at least one|provide at least one/i, visible: :hidden)
      expect(page.current_path).to include('new_outgoing_link')
    end
    
    it 'redirects to return_url after successful creation' do
      return_url = organization_goal_path(organization, goal1)
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1, return_url: return_url, return_text: 'Goal')
      
      check "goal_ids_#{goal2.id}"
      click_button 'Create Links', id: 'create-existing-links-btn'
      
      expect(page).to have_current_path(return_url)
      # Check for toast element in DOM (may not be visible immediately due to JS)
      expect(page).to have_css('.toast', text: 'Goal link was successfully created', visible: :hidden)
    end
    
    it 'returns to return_url without creating links when cancel is clicked' do
      return_url = organization_goal_path(organization, goal1)
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1, return_url: return_url, return_text: 'Goal')
      
      # Find the cancel link - there are two, use the first one
      first('a.btn-outline-secondary', text: /Goal|Cancel/).click
      
      expect(page).to have_current_path(return_url)
      expect(GoalLink.count).to eq(0)
    end
  end
  
  describe 'circular dependency prevention' do
    it 'disables checkboxes for goals that would create circular dependencies' do
      # Create goal chain: goal1 -> goal2 -> goal3
      create(:goal_link, parent: goal1, child: goal2)
      create(:goal_link, parent: goal2, child: goal3)
      
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal3)
      
      # Goal1 should be disabled (would create cycle: goal3 -> goal1, but goal1 -> goal2 -> goal3 exists)
      # Actually, goal1 wouldn't create a cycle directly, but let's check goal2 which would
      # goal3 -> goal2 would create: goal3 -> goal2, but goal2 -> goal3 exists (cycle!)
      
      # Goal2 should be disabled because it would create a direct cycle
      goal2_checkbox = find("input#goal_ids_#{goal2.id}")
      expect(goal2_checkbox).to be_disabled
      
      # Goal1 might also be disabled if it would create a transitive cycle
      # goal3 -> goal1: goal3 -> goal1, but goal1 -> goal2 -> goal3 exists (cycle!)
      goal1_checkbox = find("input#goal_ids_#{goal1.id}")
      expect(goal1_checkbox).to be_disabled
    end
    
    it 'allows selection of goals that don\'t create cycles' do
      # Create goal1 -> goal2 (no cycle with goal3)
      create(:goal_link, parent: goal1, child: goal2)
      
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal3)
      
      # Goal1 and goal2 should be enabled (no cycles)
      goal1_checkbox = find("input#goal_ids_#{goal1.id}")
      goal2_checkbox = find("input#goal_ids_#{goal2.id}")
      
      expect(goal1_checkbox).not_to be_disabled
      expect(goal2_checkbox).not_to be_disabled
    end
  end
  
  describe 'existing link detection' do
    it 'checks and disables already-linked goals' do
      # Create existing link
      create(:goal_link, parent: goal1, child: goal2)
      
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      # Goal2 should be checked and disabled
      goal2_checkbox = find("input#goal_ids_#{goal2.id}")
      expect(goal2_checkbox).to be_disabled
      expect(goal2_checkbox).to be_checked
      
      expect(page).to have_content('Already Linked')
    end
    
    it 'allows selection of goals that are not already linked' do
      # Create link between goal1 and goal2
      create(:goal_link, parent: goal1, child: goal2)
      
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      # Goal3 should be enabled and unchecked (not already linked)
      goal3_checkbox = find("input#goal_ids_#{goal3.id}")
      expect(goal3_checkbox).not_to be_disabled
      expect(goal3_checkbox).not_to be_checked
    end
  end
  
  describe 'privacy level visualization' do
    it 'displays privacy levels as concentric circles' do
      goal_with_privacy = create(:goal, creator: teammate, owner: teammate, title: 'Private Goal', privacy_level: 'only_creator_and_owner', goal_type: 'stepping_stone_activity')
      
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      expect(page).to have_content('🔘🔘○○ Creator & Owner')
    end
    
    it 'shows tooltip with privacy level description' do
      goal_with_privacy = create(:goal, creator: teammate, owner: teammate, title: 'Private Goal', privacy_level: 'only_creator_and_owner', goal_type: 'stepping_stone_activity')
      
      visit new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      
      # Check that privacy rings have tooltip
      privacy_span = find('span', text: /🔘🔘○○/)
      expect(privacy_span['data-bs-toggle']).to eq('tooltip')
    end
  end
end
