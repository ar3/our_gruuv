require 'rails_helper'

RSpec.describe 'Check-ins Empty State Navigation', type: :system do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }

  before do
    # Ensure person has no assignments, aspirations, or position
    teammate.assignment_tenures.destroy_all
    teammate.employment_tenures.destroy_all
    # No aspirations are created by default
    
    sign_in_as(person)
    visit organization_person_check_ins_path(organization, person)
  end

  describe 'Assignment empty state' do
    it 'shows link to check-ins page for assignment management when no assignments available' do
      expect(page).to have_content('No assignments available to do a check-in on')
      expect(page).to have_link('Manage Assignments', href: organization_person_check_ins_path(organization, person))
    end
  end

  describe 'Aspiration empty state' do
    it 'shows link to aspirations index when no aspirations available' do
      expect(page).to have_content('No aspirations available to do a check-in on')
      expect(page).to have_link('Manage Aspirations', href: organization_aspirations_path(organization))
    end
  end

  describe 'Both card and table views' do
    it 'shows navigation links in card view' do
      visit organization_person_check_ins_path(organization, person, view: 'card')
      
      expect(page).to have_link('Manage Assignments', href: organization_person_check_ins_path(organization, person))
      expect(page).to have_link('Manage Aspirations', href: organization_aspirations_path(organization))
    end

    it 'shows navigation links in table view' do
      visit organization_person_check_ins_path(organization, person, view: 'table')
      
      expect(page).to have_link('Manage Assignments', href: organization_person_check_ins_path(organization, person))
      expect(page).to have_link('Manage Aspirations', href: organization_aspirations_path(organization))
    end
  end
end
