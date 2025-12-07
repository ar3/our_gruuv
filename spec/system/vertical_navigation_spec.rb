require 'rails_helper'

RSpec.describe 'Vertical Navigation', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:user_preference) { UserPreference.for_person(person) }
  
  before do
    sign_in_as(person, organization)
    user_preference.update_preference(:layout, 'vertical')
  end
  
  describe 'navigation visibility' do
    it 'shows vertical navigation when layout is vertical' do
      visit dashboard_organization_path(organization)
      
      expect(page).to have_css('.vertical-nav')
    end
    
    it 'hides navigation by default' do
      user_preference.update_preference(:vertical_nav_open, false)
      visit dashboard_organization_path(organization)
      
      nav = page.find('.vertical-nav', visible: false)
      expect(nav).to have_css('.closed', visible: false)
    end
  end
  
  describe 'toggle functionality' do
    before do
      user_preference.update_preference(:vertical_nav_open, false)
      visit dashboard_organization_path(organization)
    end
    
    it 'opens navigation when toggle button is clicked' do
      toggle_btn = page.find('.vertical-nav-toggle-btn', visible: true)
      toggle_btn.click
      
      # Wait for animation
      sleep 0.5
      
      nav = page.find('.vertical-nav', visible: true)
      expect(nav).to have_css('.open')
    end
  end
  
  describe 'lock functionality' do
    before do
      user_preference.update_preference(:vertical_nav_open, true)
      user_preference.update_preference(:vertical_nav_locked, false)
      visit dashboard_organization_path(organization)
    end
    
    it 'locks navigation when lock button is clicked' do
      lock_btn = page.find('.vertical-nav-lock-btn')
      lock_btn.click
      
      sleep 0.5
      
      nav = page.find('.vertical-nav')
      expect(nav).to have_css('.locked')
      
      # Verify state persisted
      user_preference.reload
      expect(user_preference.vertical_nav_locked?).to eq(true)
    end
  end
  
  describe 'current page highlighting' do
    before do
      user_preference.update_preference(:vertical_nav_open, true)
      visit dashboard_organization_path(organization)
    end
    
    it 'highlights dashboard link when on dashboard' do
      nav = page.find('.vertical-nav', visible: true)
      dashboard_link = nav.find('a.nav-link.active', text: /Dashboard/i)
      
      expect(dashboard_link).to be_present
    end
  end
  
  describe 'layout switching' do
    before do
      user_preference.update_preference(:layout, 'horizontal')
      visit dashboard_organization_path(organization)
    end
    
    it 'switches to vertical layout from user menu' do
      # Open user menu
      user_menu = page.find('.nav-link.dropdown-toggle', text: person.full_name)
      user_menu.click
      
      # Click vertical navigation option
      vertical_option = page.find('.dropdown-item', text: 'Vertical Navigation')
      vertical_option.click
      
      # Should redirect and show vertical nav
      expect(page).to have_css('.vertical-nav')
      
      # Verify preference updated
      user_preference.reload
      expect(user_preference.layout).to eq('vertical')
    end
  end
end

