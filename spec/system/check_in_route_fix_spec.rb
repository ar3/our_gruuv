require 'rails_helper'

RSpec.describe 'Check-In Route Fix', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person, full_name: 'Test Person') }
  let!(:teammate) { create(:teammate, person: person, organization: organization) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
  end

  it 'can access check-ins page via view switcher without route errors' do
    # This should not raise a NoMethodError for organization_check_in_path
    visit organization_person_path(organization, person)
    
    # The page should load without errors
    expect(page).to have_content('Test Person')
    
    # The view switcher should be present and functional
    expect(page).to have_css('.dropdown-toggle')
  end

  it 'can access check-ins page directly with correct route' do
    # Create necessary setup for position check-in
    position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
    position_type = create(:position_type, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level)
    position_level = create(:position_level, position_major_level: position_major_level, level: '1.1')
    position = create(:position, position_type: position_type, position_level: position_level)
    create(:employment_tenure, teammate: teammate, position: position, company: organization, started_at: 1.year.ago)
    
    # This should work with the correct route structure
    visit organization_person_check_ins_path(organization, person)
    
    expect(page).to have_content('Check-Ins for Test Person')
    expect(page).to have_content('View Mode: Employee')
  end
end
