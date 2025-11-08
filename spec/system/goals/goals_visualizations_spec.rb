require 'rails_helper'

RSpec.describe 'Goals Visualizations', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization) }
  
  before do
    # Ensure teammate exists before stubbing (let! makes it eager)
    teammate
    # Set current organization for the person
    person.update!(current_organization: organization)
    # Use proper authentication for system specs
    sign_in_as(person, organization)
  end
  
  after do
    # Clear any modal state that might persist
    if page.has_css?('#goalsFilterModal', visible: true, wait: 0)
      # Use native JavaScript to hide modal instead of jQuery
      page.execute_script("document.getElementById('goalsFilterModal')?.classList.remove('show'); document.body.classList.remove('modal-open');")
    end
  end
  
  # Helper method to select owner via UI
  def select_owner_in_modal
    # Clear any existing modal state
    if page.has_css?('#goalsFilterModal', visible: true, wait: 0)
      page.execute_script("document.getElementById('goalsFilterModal')?.classList.remove('show'); document.body.classList.remove('modal-open');")
      sleep 0.5
    end
    
    click_button 'Filter & Sort'
    # Wait for modal to be visible
    expect(page).to have_css('#goalsFilterModal', visible: true, wait: 5)
    
    within('#goalsFilterModal') do
      # Find the select field
      owner_select = find('select[name="owner_id"]', wait: 5)
      
      # The select uses format "Teammate_123" for the value, label is "Teammate: Person Name"
      option_text = "Teammate: #{person.display_name}"
      option_value = "Teammate_#{teammate.id}"
      
      # Select by text directly (don't try to clear first - causes ambiguous match)
      owner_select.select(option_text)
      
      # Verify selection was made
      expect(owner_select.value).to eq(option_value)
      
      # Submit the form
      click_button 'Apply Filters'
    end
    
    # Wait for form submission - check that URL changes or modal closes
    # The form submits via GET, so we should see a page reload
    expect(page).not_to have_css('#goalsFilterModal', visible: true, wait: 10)
    
    # Wait for the "Please select" message to disappear and goals to appear
    expect(page).not_to have_content('Please select an owner to view goals', wait: 10)
  end
  
  describe 'view style switching' do
    let!(:goal1) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        company: organization.root_company || organization,
        title: 'Test Goal 1',
        goal_type: 'inspirational_objective',
        most_likely_target_date: Date.today + 1.month,
        privacy_level: 'everyone_in_company'
      )
    end
    
    let!(:goal2) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        company: organization.root_company || organization,
        title: 'Test Goal 2',
        goal_type: 'quantitative_key_result',
        most_likely_target_date: Date.today + 2.months,
        privacy_level: 'everyone_in_company'
      )
    end
    
    it 'preserves filters when switching view styles' do
      visit organization_goals_path(organization)
      
      # Select owner first
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        select "Teammate: #{person.display_name}", from: 'owner_id'
        click_button 'Apply Filters'
      end
      
      # Should see goals now
      expect(page).to have_content('Test Goal 1')
      
      # Open filter modal again
      click_button 'Filter & Sort'
      expect(page).to have_css('#goalsFilterModal', visible: true)
      
      # Apply a filter
      within('#goalsFilterModal') do
        find('#goal_type_inspirational_objective').check
        click_button 'Apply Filters'
      end
      
      # Should only see goal1
      expect(page).to have_content('Test Goal 1')
      expect(page).not_to have_content('Test Goal 2')
      
      # Switch to network view
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        # Find and click the network view radio button
        find('input[type="radio"][value="network"]').choose
        click_button 'Apply Filters'
      end
      
      # Wait for page to reload with network view
      expect(page).to have_current_path(/#{Regexp.escape(organization_goals_path(organization))}/, wait: 10)
      expect(page).to have_css('.network-visualization', wait: 5)
      
      # Should still only see goal1 (filter preserved)
      expect(page).to have_content('Test Goal 1')
      expect(page).not_to have_content('Test Goal 2')
      
      # URL should preserve filter params
      expect(current_url).to include('goal_type%5B%5D=inspirational_objective')
      expect(current_url).to include('view=network')
    end
    
    it 'switches between visualization views' do
      visit organization_goals_path(organization)
      
      # Select owner first
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        select "Teammate: #{person.display_name}", from: 'owner_id'
        click_button 'Apply Filters'
      end
      
      # Should see table view
      expect(page).to have_css('table.table')
      
      # Switch to network view
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        # Find and click the network view radio button
        find('input[type="radio"][value="network"]').choose
        click_button 'Apply Filters'
      end
      
      # Wait for page to reload
      expect(page).to have_current_path(/#{Regexp.escape(organization_goals_path(organization))}/, wait: 10)
      expect(current_url).to include('view=network')
      expect(page).to have_css('.network-visualization', wait: 5)
      
      # Switch to tree view
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        choose 'view_tree'
        click_button 'Apply Filters'
      end
      
      expect(current_url).to include('view=tree')
      expect(page).to have_css('.tree-visualization')
      
      # Switch to nested view
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        choose 'view_nested'
        click_button 'Apply Filters'
      end
      
      expect(current_url).to include('view=nested')
      expect(page).to have_css('.nested-visualization')
      
      # Switch to timeline view
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        choose 'view_timeline'
        click_button 'Apply Filters'
      end
      
      expect(current_url).to include('view=timeline')
      expect(page).to have_css('.timeline-visualization')
    end
  end
  
  describe 'performance warning' do
    before do
      # Create 101 goals to trigger warning
      101.times do |i|
        create(:goal,
          creator: teammate,
          owner: teammate,
          company: organization.root_company || organization,
          title: "Goal #{i + 1}",
          goal_type: 'inspirational_objective',
          privacy_level: 'everyone_in_company'
        )
      end
    end
    
    it 'shows performance warning when goal count > 100 and visualization view is selected' do
      visit organization_goals_path(organization)
      select_owner_in_modal
      
      # Switch to network view
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        choose 'view_network'
        click_button 'Apply Filters'
      end
      
      expect(page).to have_content('Performance Warning')
      expect(page).to have_content('This visualization may be slow with 101 goals')
      
      # Switch to table view - warning should disappear
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        choose 'view_table'
        click_button 'Apply Filters'
      end
      
      expect(page).not_to have_content('Performance Warning')
    end
    
    it 'does not show warning for table view even with many goals' do
      visit organization_goals_path(organization)
      select_owner_in_modal
      
      expect(page).not_to have_content('Performance Warning')
    end
  end
  
  describe 'visualization rendering' do
    let!(:parent_goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        company: organization.root_company || organization,
        title: 'Parent Goal',
        goal_type: 'inspirational_objective',
        most_likely_target_date: Date.today + 1.month,
        privacy_level: 'everyone_in_company'
      )
    end
    
    let!(:child_goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        company: organization.root_company || organization,
        title: 'Child Goal',
        goal_type: 'quantitative_key_result',
        most_likely_target_date: Date.today + 2.months,
        privacy_level: 'everyone_in_company'
      )
    end
    
    let!(:goal_link) do
      create(:goal_link,
        this_goal: child_goal,
        that_goal: parent_goal,
        link_type: 'this_is_key_result_of_that'
      )
    end
    
    it 'renders network view with goals and links' do
      visit organization_goals_path(organization)
      select_owner_in_modal
      
      # Switch to network view
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        choose 'view_network'
        click_button 'Apply Filters'
      end
      
      expect(page).to have_css('.network-visualization')
      expect(page).to have_css('svg')
      expect(page).to have_content('Parent Goal')
      expect(page).to have_content('Child Goal')
    end
    
    it 'renders tree view with hierarchical structure' do
      visit organization_goals_path(organization)
      select_owner_in_modal
      
      # Switch to tree view
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        choose 'view_tree'
        click_button 'Apply Filters'
      end
      
      expect(page).to have_css('.tree-visualization')
      expect(page).to have_content('Parent Goal')
      expect(page).to have_content('Child Goal')
    end
    
    it 'renders nested view with nested cards' do
      visit organization_goals_path(organization)
      select_owner_in_modal
      
      # Switch to nested view
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        choose 'view_nested'
        click_button 'Apply Filters'
      end
      
      expect(page).to have_css('.nested-visualization')
      expect(page).to have_content('Parent Goal')
      expect(page).to have_content('Child Goal')
    end
    
    it 'renders timeline view with goals by date' do
      visit organization_goals_path(organization)
      select_owner_in_modal
      
      # Switch to timeline view
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        choose 'view_timeline'
        click_button 'Apply Filters'
      end
      
      expect(page).to have_css('.timeline-visualization')
      expect(page).to have_content('Parent Goal')
      expect(page).to have_content('Child Goal')
    end
  end
  
  describe 'empty state' do
    it 'shows empty state message for visualizations when no goals exist' do
      visit organization_goals_path(organization)
      select_owner_in_modal
      
      # Switch to network view
      click_button 'Filter & Sort'
      within('#goalsFilterModal') do
        # Find and click the network view radio button
        find('input[type="radio"][value="network"]').choose
        click_button 'Apply Filters'
      end
      
      # Wait for network view to load
      expect(page).to have_current_path(/#{Regexp.escape(organization_goals_path(organization))}/, wait: 10)
      expect(page).to have_css('.network-visualization', wait: 5)
      
      # Should show empty state message (either "No goals to visualize" or "No goals match your current filters")
      expect(page).to have_content(/No goals (to visualize|match your current filters)/)
      expect(page).to have_content(/Create goals|Try adjusting your filters/)
    end
  end
end


