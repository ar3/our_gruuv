require 'rails_helper'

RSpec.describe 'Aspiration CRUD Flow', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:maap_user) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: false) }
  let!(:maap_teammate) { create(:teammate, person: maap_user, organization: organization, can_manage_maap: true) }

  describe 'Complete Aspiration CRUD Flow' do
    context 'when user has MAAP permissions' do
      before do
        # Mock authentication
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(maap_user)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
        allow(maap_user).to receive(:can_manage_maap?).and_return(true)
      end

      it 'performs full CRUD operations: index -> new -> create -> show -> index' do
        # Step 1: Visit the aspirations index
        visit organization_aspirations_path(organization)
        
        # Should see the aspirations index page
        expect(page).to have_content('Aspirations')
        expect(page).to have_link(href: new_organization_aspiration_path(organization))
        
        # Step 2: Click to create a new aspiration
        first(:link, href: new_organization_aspiration_path(organization)).click
        
        # Should be on the new aspiration form
        expect(page).to have_content('New Aspiration')
        expect(page).to have_field('aspiration_name')
        expect(page).to have_field('aspiration_description')
        expect(page).to have_field('aspiration_sort_order')
        expect(page).to have_button('Create Aspiration')
        
        # Step 3: Fill out and submit the form
        fill_in 'aspiration_name', with: 'Test Aspiration'
        fill_in 'aspiration_description', with: 'This is a test aspiration for our system test'
        fill_in 'aspiration_sort_order', with: '10'
        
        click_button 'Create Aspiration'
        
        # Step 4: Should be redirected to index with success message
        expect(page).to have_content('Aspiration was successfully created')
        expect(page).to have_content('Aspirations')
        
        # Should see the new aspiration in the list
        expect(page).to have_content('Test Aspiration')
        
        # Step 5: Click on the aspiration to view its show page
        click_link 'Test Aspiration'
        
        # Should be on the aspiration show page
        expect(page).to have_content('Test Aspiration')
        expect(page).to have_content('This is a test aspiration for our system test')
        
        # Step 6: Go back to index to verify it's still there
        click_link 'Back to Aspirations'
        
        # Should be back on index with the aspiration still visible
        expect(page).to have_content('Aspirations')
        expect(page).to have_content('Test Aspiration')
      end

      it 'shows validation errors for missing required fields' do
        visit new_organization_aspiration_path(organization)
        
        # Try to submit empty form
        click_button 'Create Aspiration'
        
        # Should show validation errors
        expect(page).to have_content('Name can\'t be blank')
        
        # Should stay on form
        expect(page).to have_content('New Aspiration')
      end

      it 'handles organization selection properly' do
        # Create a child organization
        child_org = create(:organization, :company, parent: organization)
        create(:teammate, person: maap_user, organization: child_org, can_manage_maap: true)
        
        visit new_organization_aspiration_path(organization)
        
        # Should see organization dropdown
        expect(page).to have_select('aspiration_organization_id')
        
        # Select child organization
        select child_org.name, from: 'aspiration_organization_id'
        
        # Fill out form
        fill_in 'aspiration_name', with: 'Child Org Aspiration'
        fill_in 'aspiration_description', with: 'Aspiration for child organization'
        fill_in 'aspiration_sort_order', with: '5'
        
        click_button 'Create Aspiration'
        
        # Should be redirected with success
        expect(page).to have_content('Aspiration was successfully created')
        
        # Verify the aspiration was created for the correct organization
        aspiration = Aspiration.find_by(name: 'Child Org Aspiration')
        expect(aspiration.organization.id).to eq(child_org.id)
      end

      it 'prevents duplicate aspiration names within same organization' do
        # Create an existing aspiration
        existing_aspiration = create(:aspiration, organization: organization, name: 'Existing Aspiration')
        
        visit new_organization_aspiration_path(organization)
        
        # Try to create another with same name
        fill_in 'aspiration_name', with: 'Existing Aspiration'
        fill_in 'aspiration_description', with: 'Duplicate name test'
        fill_in 'aspiration_sort_order', with: '15'
        
        click_button 'Create Aspiration'
        
        # Should show validation error
        expect(page).to have_content('Name has already been taken')
        
        # Should stay on form
        expect(page).to have_content('New Aspiration')
      end

      it 'allows same aspiration name in different organizations' do
        # Create a child organization within the same company
        other_org = create(:organization, :company, parent: organization)
        create(:teammate, person: maap_user, organization: other_org, can_manage_maap: true)
        
        # Create aspiration in first organization
        create(:aspiration, organization: organization, name: 'Shared Name')
        
        visit new_organization_aspiration_path(organization)
        
        # Select other organization
        select other_org.name, from: 'aspiration_organization_id'
        
        # Try to create with same name but different organization
        fill_in 'aspiration_name', with: 'Shared Name'
        fill_in 'aspiration_description', with: 'Same name, different org'
        fill_in 'aspiration_sort_order', with: '20'
        
        click_button 'Create Aspiration'
        
        # Should succeed
        expect(page).to have_content('Aspiration was successfully created')
        
        # Verify both aspirations exist
        expect(Aspiration.where(name: 'Shared Name').count).to eq(2)
      end
    end

    context 'when user is a regular teammate' do
      before do
        # Mock authentication
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
        allow(person).to receive(:can_manage_maap?).and_return(false)
      end

      it 'can view aspirations but sees disabled buttons with warning icons' do
        # Create an aspiration to view
        aspiration = create(:aspiration, organization: organization, name: 'Test Aspiration')
        
        # Visit the aspirations index
        visit organization_aspirations_path(organization)
        
        # Should see the aspirations index page
        expect(page).to have_content('Aspirations')
        expect(page).to have_content('Test Aspiration')
        
        # Should see disabled create button with warning icon
        expect(page).to have_css('.btn-primary.disabled')
        expect(page).to have_css('.bi-exclamation-triangle')
        expect(page).to have_css('[data-bs-title*="MAAP management permission"]')
        
        # Should see disabled edit and delete buttons in table
        expect(page).to have_css('.btn-outline-secondary[disabled]')
        expect(page).to have_css('.btn-outline-danger[disabled]')
        
        # Click on aspiration to view show page
        click_link 'Test Aspiration'
        
        # Should be on the aspiration show page
        expect(page).to have_content('Test Aspiration')
        
        # Should see disabled edit button with warning icon
        expect(page).to have_css('.btn-outline-secondary[disabled]')
        expect(page).to have_css('.bi-exclamation-triangle')
        expect(page).to have_css('[data-bs-title*="MAAP management permission"]')
      end
    end
  end
end
