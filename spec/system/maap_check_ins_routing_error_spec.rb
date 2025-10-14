require 'rails_helper'

RSpec.describe 'MAAP Check-Ins Routing Error', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person, full_name: 'Natalie Test') }
  let!(:teammate) { create(:teammate, person: person, organization: organization) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
  end

  it 'shows proper routing error for incorrect URL structure' do
    # Visit the incorrect URL structure that was causing the original error
    visit "/organizations/#{organization.id}/check_ins/#{person.id}"
    
    # Should show Rails routing error page
    expect(page).to have_content('Routing Error')
    expect(page).to have_content('No route matches')
    expect(page).to have_content("/organizations/#{organization.id}/check_ins/#{person.id}")
  end

  it 'works correctly with proper nested route structure' do
    # Create necessary setup for position check-in
    position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
    position_type = create(:position_type, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level)
    position_level = create(:position_level, position_major_level: position_major_level, level: '1.1')
    position = create(:position, position_type: position_type, position_level: position_level)
    create(:employment_tenure, teammate: teammate, position: position, company: organization, started_at: 1.year.ago)
    
    # This should work with the correct route structure
    visit "/organizations/#{organization.id}/people/#{person.id}/check_ins"
    
    expect(page).to have_content('Check-Ins for Natalie Test')
    expect(page).to have_content('View Mode: Employee')
  end
end
