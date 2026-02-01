require 'rails_helper'

RSpec.describe 'Aspiration CRUD Flow', type: :system do
  let(:company) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: company) }
  let(:person) { create(:person) }
  let(:maap_user) { create(:person) }
  let!(:company_teammate) { CompanyTeammate.create!(person: maap_user, organization: company, can_manage_maap: true) }
  let!(:department_teammate) { CompanyTeammate.create!(person: maap_user, organization: department, can_manage_maap: true) }

  describe 'Complete Aspiration CRUD Flow' do
    context 'when user has MAAP permissions' do
      before do
        sign_in_as(maap_user, company)
      end

      it 'performs full CRUD operations on company: index -> new -> create -> show -> index' do
        # Step 1: Visit the aspirations index
        visit organization_aspirations_path(company)
        
        # Should see the aspirations index page
        expect(page).to have_content('Aspirations')
        expect(page).to have_link(href: new_organization_aspiration_path(company))
        
        # Step 2: Click to create a new aspiration
        first(:link, href: new_organization_aspiration_path(company)).click
        
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
        # Check flash message (may be in DOM but not visible in toast)
        expect(page).to have_success_flash('Aspiration was successfully created')
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

      it 'performs full CRUD operations on department' do
        # Create aspiration on department
        visit new_organization_aspiration_path(department)
        expect(page).to have_content('New Aspiration')
        
        fill_in 'aspiration_name', with: 'Department Aspiration'
        fill_in 'aspiration_description', with: 'Aspiration for department'
        fill_in 'aspiration_sort_order', with: '5'
        
        click_button 'Create Aspiration'
        
        expect(page).to have_success_flash('Aspiration was successfully created')
        expect(page).to have_content('Department Aspiration')
        
        aspiration = Aspiration.last
        expect(aspiration.company).to be_a(Organization)
        expect(aspiration.company.id).to eq(department.id)
        
        # View on department index
        visit organization_aspirations_path(department)
        expect(page).to have_content('Department Aspiration')
        
        # Update
        visit edit_organization_aspiration_path(department, aspiration)
        fill_in 'aspiration_name', with: 'Updated Department Aspiration'
        # Select version type for update
        choose 'version_type_insignificant'
        click_button 'Update Aspiration'
        
        expect(page).to have_content('Updated Department Aspiration')
        aspiration.reload
        expect(aspiration.name).to eq('Updated Department Aspiration')
      end

      it 'shows validation errors for missing required fields' do
        visit new_organization_aspiration_path(company)
        
        # Try to submit empty form
        click_button 'Create Aspiration'
        
        # Should show validation errors
        expect(page).to have_content('Name can\'t be blank')
        
        # Should stay on form
        expect(page).to have_content('New Aspiration')
      end

      it 'handles department selection properly' do
        # Create a department
        department = create(:organization, :department, parent: company)
        
        visit new_organization_aspiration_path(company)
        
        # Should see department dropdown
        expect(page).to have_select('aspiration_department_id')
        
        # Fill out form
        fill_in 'aspiration_name', with: 'Department Aspiration'
        fill_in 'aspiration_sort_order', with: '5'
        
        click_button 'Create Aspiration'
        
        # Should be redirected with success
        expect(page).to have_success_flash('Aspiration was successfully created')
        
        # Verify the aspiration was created
        aspiration = Aspiration.find_by(name: 'Department Aspiration')
        expect(aspiration.company.id).to eq(company.id)
      end

      it 'prevents duplicate aspiration names within same organization' do
        # Create an existing aspiration
        existing_aspiration = create(:aspiration, company: company, name: 'Existing Aspiration')
        
        visit new_organization_aspiration_path(company)
        
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
        other_org = create(:organization, :company, parent: company)
        CompanyTeammate.create!(person: maap_user, organization: other_org, can_manage_maap: true)
        
        # Create aspiration in first organization
        create(:aspiration, company: company, name: 'Shared Name')
        
        visit new_organization_aspiration_path(company)
        
        # Select other organization
        select other_org.name, from: 'aspiration_organization_id'
        
        # Try to create with same name but different organization
        fill_in 'aspiration_name', with: 'Shared Name'
        fill_in 'aspiration_description', with: 'Same name, different org'
        fill_in 'aspiration_sort_order', with: '20'
        
        click_button 'Create Aspiration'
        
        # Should succeed
        expect(page).to have_success_flash('Aspiration was successfully created')
        
        # Verify both aspirations exist
        expect(Aspiration.where(name: 'Shared Name').count).to eq(2)
      end
    end

    context 'when user is a regular teammate' do
      let!(:regular_teammate) { CompanyTeammate.create!(person: person, organization: company, can_manage_maap: false) }
      
      before do
        sign_in_as(person, company)
      end

      it 'can view aspirations but sees disabled buttons with warning icons' do
        # Create an aspiration to view
        aspiration = create(:aspiration, company: company, name: 'Test Aspiration')
        
        # Visit the aspirations index
        visit organization_aspirations_path(company)
        
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
