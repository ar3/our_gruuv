require 'rails_helper'

RSpec.describe 'New Hire Observable Moment Flow', type: :system do
  let(:company) { create(:organization, :company) }
  let(:manager_person) { create(:person) }
  let(:manager_teammate) { create(:teammate, organization: company, person: manager_person) }
  let(:new_hire_person) { create(:person) }
  let(:new_hire_teammate) { create(:teammate, organization: company, person: new_hire_person) }
  let(:position) { create(:position, company: company) }
  
  before do
    sign_in_as(manager_person, company)
  end
  
  describe 'complete flow from moment creation to observation' do
    it 'creates moment, displays in dashboard, and allows creating observation' do
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
      
      # Visit dashboard
      visit get_shit_done_organization_path(company)
      
      expect(page).to have_content('New Hire')
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
    
    it 'allows reassigning observable moment' do
      observable_moment = create(:observable_moment,
                                 :new_hire,
                                 company: company,
                                 primary_potential_observer: manager_teammate)
      other_teammate = create(:teammate, organization: company)
      
      visit get_shit_done_organization_path(company)
      
      click_link 'Reassign'
      
      expect(current_path).to eq(reassign_organization_observable_moment_path(company, observable_moment))
      expect(page).to have_content('Reassign Observable Moment')
      
      select other_teammate.person.display_name, from: 'teammate_id'
      click_button 'Reassign'
      
      expect(current_path).to eq(get_shit_done_organization_path(company))
      expect(observable_moment.reload.primary_potential_observer).to eq(other_teammate)
    end
    
    it 'allows ignoring observable moment' do
      observable_moment = create(:observable_moment,
                                 :new_hire,
                                 company: company,
                                 primary_potential_observer: manager_teammate)
      
      visit get_shit_done_organization_path(company)
      
      click_button 'Ignore'
      
      expect(current_path).to eq(get_shit_done_organization_path(company))
      expect(observable_moment.reload.processed?).to be true
      expect(observable_moment.ignored?).to be true
      
      # Moment should no longer appear in dashboard
      visit get_shit_done_organization_path(company)
      expect(page).not_to have_content(observable_moment.display_name)
    end
  end
end

