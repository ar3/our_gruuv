require 'rails_helper'

RSpec.describe 'Aspiration Check-In Integration', type: :system do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person, full_name: 'Manager Guy') }
  let(:employee) { create(:person, full_name: 'Employee Person') }
  let(:aspiration1) { create(:aspiration, organization: organization, name: 'Career Growth') }
  let(:aspiration2) { create(:aspiration, organization: organization, name: 'Technical Skills') }
  
  before do
    # Create teammate records
    manager_teammate = create(:teammate, person: manager, organization: organization)
    employee_teammate = create(:teammate, person: employee, organization: organization)
    
    # Create employment tenure
    create(:employment_tenure, teammate: employee_teammate, company: organization, manager: manager)
    
    # Create aspirations
    aspiration1
    aspiration2
  end

  describe 'Full Aspiration Check-In Workflow' do
    it 'allows employee and manager to complete aspiration check-ins and shows them on finalization page' do
      # Step 1: Employee completes aspiration check-ins
      sign_in_as(employee, organization)
      visit organization_person_check_ins_path(organization, employee)
      
      # Should see aspiration check-in forms
      expect(page).to have_content('Aspiration: Career Growth')
      expect(page).to have_content('Aspiration: Technical Skills')
      
      # Employee fills out first aspiration
      within('.card', text: 'Aspiration: Career Growth') do
        select 'Meeting', from: "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][employee_rating]"
        fill_in "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][employee_private_notes]", 
                with: 'Making good progress on career development goals'
        choose "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][status]_complete"
      end
      
      # Employee fills out second aspiration
      within('.card', text: 'Aspiration: Technical Skills') do
        select 'Exceeding', from: "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration2).id}][employee_rating]"
        fill_in "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration2).id}][employee_private_notes]", 
                with: 'Excelled in learning new technologies'
        choose "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration2).id}][status]_complete"
      end
      
      click_button 'Save All Check-Ins'
      
      # Should see success message
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 2: Manager completes aspiration check-ins
      sign_in_as(manager, organization)
      visit organization_person_check_ins_path(organization, employee)
      
      # Should see aspiration check-in forms with employee data
      within('.card', text: 'Aspiration: Career Growth') do
        expect(page).to have_content('Meeting')
        expect(page).to have_content('Making good progress on career development goals')
        
        select 'Meeting', from: "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][manager_rating]"
        fill_in "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][manager_private_notes]", 
                with: 'Employee shows strong career development initiative'
        choose "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][status]_complete"
      end
      
      within('.card', text: 'Aspiration: Technical Skills') do
        expect(page).to have_content('Exceeding')
        expect(page).to have_content('Excelled in learning new technologies')
        
        select 'Exceeding', from: "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration2).id}][manager_rating]"
        fill_in "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration2).id}][manager_private_notes]", 
                with: 'Outstanding technical growth and contribution'
        choose "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration2).id}][status]_complete"
      end
      
      click_button 'Save All Check-Ins'
      
      # Should see success message
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 3: Manager goes to finalization page
      visit organization_person_finalization_path(organization, employee)
      
      # Should see aspiration check-ins ready for finalization
      expect(page).to have_content('Aspiration Check-Ins')
      expect(page).to have_content('Finalize Aspirations')
      
      within('.aspiration-finalization', text: 'Career Growth') do
        expect(page).to have_content('Employee Perspective')
        expect(page).to have_content('Meeting')
        expect(page).to have_content('Making good progress on career development goals')
        
        expect(page).to have_content('Manager Perspective')
        expect(page).to have_content('Meeting')
        expect(page).to have_content('Employee shows strong career development initiative')
        
        # Should have finalization form
        expect(page).to have_select("aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][official_rating]")
        expect(page).to have_field("aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][shared_notes]")
      end
      
      within('.aspiration-finalization', text: 'Technical Skills') do
        expect(page).to have_content('Employee Perspective')
        expect(page).to have_content('Exceeding')
        expect(page).to have_content('Excelled in learning new technologies')
        
        expect(page).to have_content('Manager Perspective')
        expect(page).to have_content('Exceeding')
        expect(page).to have_content('Outstanding technical growth and contribution')
        
        # Should have finalization form
        expect(page).to have_select("aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration2).id}][official_rating]")
        expect(page).to have_field("aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration2).id}][shared_notes]")
      end
      
      # Step 4: Manager finalizes aspiration check-ins
      within('.aspiration-finalization', text: 'Career Growth') do
        select '🔵 Meeting', from: "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][official_rating]"
        fill_in "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][shared_notes]", 
                with: 'Continue focusing on leadership development opportunities'
      end
      
      within('.aspiration-finalization', text: 'Technical Skills') do
        select '🟢 Exceeding', from: "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration2).id}][official_rating]"
        fill_in "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration2).id}][shared_notes]", 
                with: 'Excellent technical growth. Consider mentoring others.'
      end
      
      click_button 'Finalize Selected Check-Ins'
      
      # Should see success message
      expect(page).to have_content('Check-ins finalized successfully')
      
      # Step 5: Verify aspiration check-ins are finalized
      aspiration_check_in1 = AspirationCheckIn.find_by(aspiration: aspiration1)
      aspiration_check_in2 = AspirationCheckIn.find_by(aspiration: aspiration2)
      
      expect(aspiration_check_in1.official_rating).to eq('meeting')
      expect(aspiration_check_in1.shared_notes).to eq('Continue focusing on leadership development opportunities')
      expect(aspiration_check_in1.official_check_in_completed_at).to be_present
      expect(aspiration_check_in1.finalized_by).to eq(manager)
      
      expect(aspiration_check_in2.official_rating).to eq('exceeding')
      expect(aspiration_check_in2.shared_notes).to eq('Excellent technical growth. Consider mentoring others.')
      expect(aspiration_check_in2.official_check_in_completed_at).to be_present
      expect(aspiration_check_in2.finalized_by).to eq(manager)
    end

    it 'does not show aspiration check-ins on finalization page if not ready' do
      # Employee completes aspiration check-ins but doesn't mark as ready
      sign_in_as(employee, organization)
      visit organization_person_check_ins_path(organization, employee)
      
      within('.card', text: 'Aspiration: Career Growth') do
        select 'Meeting', from: "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][employee_rating]"
        fill_in "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][employee_private_notes]", 
                with: 'Making good progress'
        choose "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][status]_draft"
      end
      
      click_button 'Save All Check-Ins'
      
      # Manager goes to finalization page
      sign_in_as(manager, organization)
      visit organization_person_finalization_path(organization, employee)
      
      # Should not see aspiration check-ins
      expect(page).not_to have_content('Aspiration Check-Ins')
      expect(page).to have_content('No check-ins are ready for finalization')
    end

    it 'shows aspiration check-ins on finalization page when both employee and manager are ready' do
      # Employee marks aspiration as ready
      sign_in_as(employee, organization)
      visit organization_person_check_ins_path(organization, employee)
      
      within('.card', text: 'Aspiration: Career Growth') do
        select 'Meeting', from: "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][employee_rating]"
        choose "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][status]_complete"
      end
      
      click_button 'Save All Check-Ins'
      
      # Manager marks aspiration as ready
      sign_in_as(manager, organization)
      visit organization_person_check_ins_path(organization, employee)
      
      within('.card', text: 'Aspiration: Career Growth') do
        select 'Meeting', from: "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][manager_rating]"
        choose "aspiration_check_ins[#{AspirationCheckIn.find_by(aspiration: aspiration1).id}][status]_complete"
      end
      
      click_button 'Save All Check-Ins'
      
      # Manager goes to finalization page
      visit organization_person_finalization_path(organization, employee)
      
      # Should see aspiration check-ins ready for finalization
      expect(page).to have_content('Aspiration Check-Ins')
      expect(page).to have_content('Career Growth')
    end
  end
end
