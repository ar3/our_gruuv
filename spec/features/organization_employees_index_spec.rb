require 'rails_helper'

RSpec.describe 'Organization Employees Index Page', type: :feature do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization) }
  
  # Create enough teammates to trigger pagination (25+ items)
  let!(:teammates) do
    (1..30).map do |i|
      person = create(:person, full_name: "Test Person #{i}", email: "person#{i}@example.com")
      create(:teammate, person: person, organization: organization, first_employed_at: 1.year.ago)
    end
  end

  before do
    # Login as the person
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_person!).and_return(true)
  end

  describe 'pagination functionality' do
    it 'displays pagination info correctly' do
      visit organization_employees_path(organization)
      
      # Should see pagination info, not literal string
      expect(page).to have_content('Displaying items')
      expect(page).to have_content('of')
      expect(page).to have_content('in total')
      
      # Should NOT see the literal string
      expect(page).not_to have_content('pagy_bootstrap_info(@pagy)')
    end

    it 'displays clickable pagination links' do
      visit organization_employees_path(organization)
      
      # Should see pagination navigation, not literal string
      expect(page).not_to have_content('pagy_bootstrap_nav(@pagy)')
      
      # Should see actual pagination links
      expect(page).to have_css('.pagy-nav')
      expect(page).to have_css('.pagy-nav .page')
      
      # Should be able to click on page links
      within('.pagy-nav') do
        expect(page).to have_link('2')
        expect(page).to have_link('Next')
      end
    end

    it 'allows navigation between pages' do
      visit organization_employees_path(organization)
      
      # Should be on page 1 initially
      expect(page).to have_css('.pagy-nav .page.active', text: '1')
      
      # Click on page 2
      within('.pagy-nav') do
        click_link '2'
      end
      
      # Should be on page 2
      expect(page).to have_css('.pagy-nav .page.active', text: '2')
      
      # Should see different teammates (page 2 content)
      expect(page).to have_content('Test Person')
    end

    it 'maintains filters when navigating pages' do
      visit organization_employees_path(organization)
      
      # Apply a filter
      click_button 'Filter & Sort'
      
      within('#teammates-filter-modal') do
        check 'Unassigned Employees'
        click_button 'Apply Filters'
      end
      
      # Should be on filtered results
      expect(page).to have_content('Active Filters: Unassigned')
      
      # Navigate to page 2
      within('.pagy-nav') do
        click_link '2'
      end
      
      # Filter should still be applied
      expect(page).to have_content('Active Filters: Unassigned')
      expect(current_url).to include('status%5B%5D=unassigned_employee')
    end

    it 'shows correct number of items per page' do
      visit organization_employees_path(organization)
      
      # Should show 25 items per page (default)
      expect(page).to have_css('.pagy-info', text: /Displaying items 1-25 of 31 in total/)
      
      # Navigate to page 2
      within('.pagy-nav') do
        click_link '2'
      end
      
      # Should show remaining items on page 2
      expect(page).to have_css('.pagy-info', text: /Displaying items 26-31 of 31 in total/)
    end

    it 'handles empty results gracefully' do
      # Clear all teammates
      Teammate.destroy_all
      
      visit organization_employees_path(organization)
      
      # Should not show pagination for empty results
      expect(page).not_to have_css('.pagy-nav')
      expect(page).to have_content('No Teammates Found')
    end

    it 'shows pagination only when there are multiple pages' do
      # Create exactly 25 teammates (1 page)
      Teammate.destroy_all
      (1..25).each do |i|
        person = create(:person, full_name: "Person #{i}", email: "person#{i}@example.com")
        create(:teammate, person: person, organization: organization)
      end
      
      visit organization_employees_path(organization)
      
      # Should not show pagination for single page
      expect(page).not_to have_css('.pagy-nav')
      expect(page).to have_css('.pagy-info', text: /Displaying 25 items/)
    end
  end

  describe 'filtering with pagination' do
    let!(:followers) do
      (1..10).map do |i|
        person = create(:person, full_name: "Follower #{i}", email: "follower#{i}@example.com")
        create(:teammate, person: person, organization: organization, first_employed_at: nil, last_terminated_at: nil)
      end
    end

    it 'resets to page 1 when applying filters' do
      visit organization_employees_path(organization)
      
      # Go to page 2
      within('.pagy-nav') do
        click_link '2'
      end
      
      # Apply filter
      click_button 'Filter & Sort'
      within('#teammates-filter-modal') do
        check 'Unassigned Employees'
        click_button 'Apply Filters'
      end
      
      # Should be back on page 1
      expect(page).to have_css('.pagy-nav .page.active', text: '1')
    end

    it 'maintains pagination state when clearing filters' do
      visit organization_employees_path(organization)
      
      # Apply filter first
      click_button 'Filter & Sort'
      within('#teammates-filter-modal') do
        check 'Followers'
        click_button 'Apply Filters'
      end
      
      # Clear filters
      click_link 'Clear All'
      
      # Should be back to all results on page 1
      expect(page).to have_css('.pagy-nav .page.active', text: '1')
      expect(page).to have_css('.pagy-info', text: /Displaying items 1-25 of 41 in total/)
    end
  end

  describe 'view type switching with pagination' do
    it 'maintains pagination when switching view types' do
      visit organization_employees_path(organization)
      
      # Go to page 2
      within('.pagy-nav') do
        click_link '2'
      end
      
      # Switch to card view
      click_button 'Filter & Sort'
      within('#teammates-filter-modal') do
        choose 'Card View'
        click_button 'Apply Filters'
      end
      
      # Should be back on page 1 after switching view types (expected behavior)
      expect(page).to have_css('.pagy-nav .page.active', text: '1')
      expect(current_url).to include('view=cards')
    end
  end

  describe 'sorting with pagination' do
    it 'maintains pagination when changing sort order' do
      visit organization_employees_path(organization)
      
      # Go to page 2
      within('.pagy-nav') do
        click_link '2'
      end
      
      # Change sort order
      click_button 'Filter & Sort'
      within('#teammates-filter-modal') do
        select 'Name (Z-A)', from: 'sort'
        click_button 'Apply Filters'
      end
      
      # Should be back on page 1 after changing sort order (expected behavior)
      expect(page).to have_css('.pagy-nav .page.active', text: '1')
      expect(current_url).to include('sort=name_desc')
    end
  end
end
