require 'rails_helper'

RSpec.describe 'New Hire Observable Moment Flow', type: :system do
  let(:company) { create(:organization, :company) }
  let(:manager_person) { create(:person) }
  let(:manager_teammate) { CompanyTeammate.find_or_create_by!(person: manager_person, organization: company) }
  let(:new_hire_person) { create(:person) }
  let(:new_hire_teammate) { CompanyTeammate.find_or_create_by!(person: new_hire_person, organization: company) }
  let(:position) { create(:position, company: company) }
  
  before do
    sign_in_as(manager_person, company)
  end
  
  describe 'complete flow from moment creation to observation' do
    xit 'creates moment, displays in dashboard, and allows creating observation' do
      # Create employment tenure (simulating new hire)
      employment_tenure = create(:employment_tenure,
                                 teammate: new_hire_teammate,
                                 company: company,
                                 manager_teammate: manager_teammate)
      
      # Manually create observable moment (normally done by service)
      observable_moment = create(:observable_moment,
                                 :new_hire,
                                 momentable: employment_tenure,
                                 company: company,
                                 primary_potential_observer: manager_teammate)
      
      # Visit dashboard (Observable Moments section may be collapsed)
      visit organization_get_shit_done_path(company)
      
      # Expand Observable Moments section if collapsed
      if page.has_css?('#observableMomentsSection.collapse:not(.show)', wait: 0)
        find('div[data-bs-target="#observableMomentsSection"]').click
      end
      expect(page).to have_content('New Hire', wait: 2)
      expect(page).to have_content(new_hire_person.display_name)
      
      # Click create observation
      click_button 'Create Observation'
      
      # Should redirect to observation form with pre-filled data
      expect(current_path).to eq(new_organization_observation_path(company))
      expect(page).to have_content('Celebrating')
      expect(page).to have_content(new_hire_person.display_name)
      
      # Form should be pre-filled
      expect(page).to have_field('observation[story]', with: /Welcome/)
      expect(page).to have_content('public_to_company')
    end
    
    xit 'allows reassigning observable moment' do
      observable_moment = create(:observable_moment,
                                 :new_hire,
                                 company: company,
                                 primary_potential_observer: manager_teammate)
      other_teammate = create(:company_teammate, organization: company)
      
      visit organization_get_shit_done_path(company)
      find('div[data-bs-target="#observableMomentsSection"]').click if page.has_css?('#observableMomentsSection.collapse:not(.show)', wait: 0)
      click_link 'Reassign'
      
      expect(current_path).to eq(reassign_organization_observable_moment_path(company, observable_moment))
      expect(page).to have_content('Reassign Observable Moment')
      
      select other_teammate.person.display_name, from: 'teammate_id'
      click_button 'Reassign'
      
      expect(current_path).to eq(organization_get_shit_done_path(company))
      expect(observable_moment.reload.primary_potential_observer).to eq(other_teammate)
    end
    
    xit 'allows ignoring observable moment' do
      observable_moment = create(:observable_moment,
                                 :new_hire,
                                 company: company,
                                 primary_potential_observer: manager_teammate)
      
      visit organization_get_shit_done_path(company)
      find('div[data-bs-target="#observableMomentsSection"]').click if page.has_css?('#observableMomentsSection.collapse:not(.show)', wait: 0)
      click_button 'Ignore'
      
      expect(current_path).to eq(organization_get_shit_done_path(company))
      expect(observable_moment.reload.processed?).to be true
      expect(observable_moment.ignored?).to be true
      
      # Moment should no longer appear in dashboard
      visit organization_get_shit_done_path(company)
      expect(page).not_to have_content(observable_moment.display_name)
    end
  end
end

