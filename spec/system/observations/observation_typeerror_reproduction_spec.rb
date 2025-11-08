require 'rails_helper'

RSpec.describe 'Observation Wizard TypeError Reproduction', type: :system do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee1) { create(:teammate, organization: company) }
  let(:ability1) { create(:ability, organization: company, name: 'Ruby Programming') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(observer)
    observer_teammate # Ensure observer teammate is created
  end

  it 'REPRODUCES THE EXACT TypeError: no implicit conversion of Array into String' do
    # This test reproduces the exact bug scenario
    
    # Debug: Check abilities before starting
    puts "Abilities before test: #{company.abilities.count}"
    puts "Ability1 organization: #{ability1.organization_id}"
    puts "Company ID: #{company.id}"
    
    # Step 1: Fill out the form and go to Step 2
    visit new_organization_observation_path(company)
    
    fill_in 'observation[story]', with: 'Great work!'
    fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
    first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
    first_teammate_checkbox.check
    
    find('input[type="submit"][value="2"]').click
    
    # Should be on Step 2
    expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
    
    # Debug: Check what's on the page
    puts "Page content: #{page.text}"
    puts "Available abilities: #{company.abilities.count}"
    
    # Verify abilities are available
    expect(page).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 1)
    
    # Step 2: Add a rating and submit without privacy level to trigger validation error
    # This will cause the form to re-render with the rating data in the session
    ability_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="ability"]')
    ability_selects.first.select('Strongly Agree (Exceptional)')
    
    # Submit without privacy level to trigger validation error and form re-rendering
    find('input[type="submit"][value="3"]').click
    
    # This should cause the TypeError because the form re-renders with Array data
    # The error occurs when the view tries to render the select_tag with Array data
    expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
    expect(page).to have_content("can't be blank")
    
    # The page should render without TypeError - if it does, our fix worked
    # If it doesn't, we'll get the exact error: "no implicit conversion of Array into String"
  end
end
