require 'rails_helper'

RSpec.describe 'Aspiration Finalization Bug Reproduction', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person, full_name: 'Natalie Morgan') }
  let(:employee) { create(:person, full_name: 'Amy Campero') }
  let(:aspiration1) { create(:aspiration, organization: organization, name: 'Work Together, Win Together') }
  let(:aspiration2) { create(:aspiration, organization: organization, name: 'Be Kind') }
  let(:aspiration3) { create(:aspiration, organization: organization, name: 'Speak Up, Step Up') }
  let(:aspiration4) { create(:aspiration, organization: organization, name: 'Keep Growing') }
  
  before do
    # Create teammate records
    manager_teammate = create(:teammate, person: manager, organization: organization, can_manage_employment: true)
    employee_teammate = create(:teammate, person: employee, organization: organization)
    
    # Create employment tenure
    create(:employment_tenure, teammate: employee_teammate, company: organization, manager: manager)
    
    # Create aspirations
    aspiration1
    aspiration2
    aspiration3
    aspiration4
    
    # Create aspiration check-ins (simulating the real data situation)
    aspiration_check_in1 = create(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration1)
    aspiration_check_in2 = create(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration2)
    aspiration_check_in3 = create(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration3)
    aspiration_check_in4 = create(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration4)
    
    # Set up the "Keep Growing" aspiration EXACTLY like the real data
    aspiration_check_in4.update!(
      employee_rating: '',  # Empty string like real data
      manager_rating: 'meeting',
      employee_private_notes: '',  # Empty string like real data
      manager_private_notes: 'KG - meeting - ready',
      employee_completed_at: 1.day.ago,
      manager_completed_at: 1.day.ago,
      manager_completed_by: manager
    )
  end

  describe 'Finalization Page Bug - Exact Reproduction' do
    it 'shows aspiration check-ins on finalization page when ready (EXACT REAL DATA SCENARIO)' do
      # Manager visits finalization page
      sign_in_as(manager, organization)
      visit organization_person_finalization_path(organization, employee)
      
      # Debug: Check what's actually on the page
      puts "Page content: #{page.text}"
      puts "Page HTML: #{page.html}"
      
      # Should see aspiration check-ins section
      expect(page).to have_content('Aspiration Check-Ins')
      expect(page).to have_content('Finalize Aspirations')
      
      # Should see the "Keep Growing" aspiration ready for finalization
      within('.aspiration-finalization', text: 'Keep Growing') do
        expect(page).to have_content('Employee Perspective')
        expect(page).to have_content('Not Rated')  # Empty string shows as "Not Rated"
        expect(page).to have_content('Manager Perspective')
        expect(page).to have_content('🔵 Meeting')
        expect(page).to have_content('KG - meeting - ready')
        
        # Should have finalization form
        aspiration_check_in = AspirationCheckIn.find_by(aspiration: aspiration4)
        expect(page).to have_select("aspiration_check_ins[#{aspiration_check_in.id}][official_rating]")
        expect(page).to have_field("aspiration_check_ins[#{aspiration_check_in.id}][shared_notes]")
      end
      
      # Should show finalization button since there are ready check-ins
      expect(page).to have_button('Finalize Selected Check-Ins')
    end

    it 'reproduces the exact bug scenario from production' do
      # This test should FAIL if aspirations are not showing
      # Manager visits finalization page
      sign_in_as(manager, organization)
      visit organization_person_finalization_path(organization, employee)
      
      # CRITICAL: This should fail if aspirations are not showing
      expect(page).to have_content('Aspiration Check-Ins'), "Aspiration Check-Ins section is missing!"
      expect(page).to have_content('Keep Growing'), "Keep Growing aspiration is missing!"
      
      # Check if the aspiration section is visible (not hidden by CSS)
      aspiration_section = page.find('.aspiration-finalization', text: 'Keep Growing')
      expect(aspiration_section).to be_visible, "Aspiration section is not visible!"
      
      # Check if the finalization button is present
      expect(page).to have_button('Finalize Selected Check-Ins'), "Finalization button is missing!"
    end

    it 'tests the exact production URL scenario' do
      # This test simulates visiting the exact production URL
      # Manager visits finalization page
      sign_in_as(manager, organization)
      visit organization_person_finalization_path(organization, employee)
      
      # Debug: Print the actual URL being visited
      puts "Visiting URL: #{current_url}"
      
      # Check if the page loads without errors
      expect(page).to have_content('Finalize Check-Ins for Amy Campero')
      
      # Check if aspiration check-ins section exists
      if page.has_content?('Aspiration Check-Ins')
        puts "✅ Aspiration Check-Ins section found"
        
        # Check if the specific aspiration is there
        if page.has_content?('Keep Growing')
          puts "✅ Keep Growing aspiration found"
          
          # Check if the finalization form is there
          aspiration_check_in = AspirationCheckIn.find_by(aspiration: aspiration4)
          if page.has_select?("aspiration_check_ins[#{aspiration_check_in.id}][official_rating]")
            puts "✅ Finalization form found"
          else
            puts "❌ Finalization form missing"
          end
        else
          puts "❌ Keep Growing aspiration missing"
        end
      else
        puts "❌ Aspiration Check-Ins section missing"
        
        # Debug: Print what's actually on the page
        puts "Page content: #{page.text}"
      end
      
      # The test should pass if aspirations are showing
      expect(page).to have_content('Aspiration Check-Ins')
      expect(page).to have_content('Keep Growing')
    end

    it 'does not show aspiration check-ins that are not ready' do
      # Manager visits finalization page
      sign_in_as(manager, organization)
      visit organization_person_finalization_path(organization, employee)
      
      # Should not see the other aspirations that are not ready
      expect(page).not_to have_content('Work Together, Win Together')
      expect(page).not_to have_content('Be Kind')
      expect(page).not_to have_content('Speak Up, Step Up')
      
      # Should only see the ready one
      expect(page).to have_content('Keep Growing')
    end

    it 'allows manager to finalize aspiration check-ins' do
      # Manager visits finalization page
      sign_in_as(manager, organization)
      visit organization_person_finalization_path(organization, employee)
      
      # Fill out finalization form
      aspiration_check_in = AspirationCheckIn.find_by(aspiration: aspiration4)
      within('.aspiration-finalization', text: 'Keep Growing') do
        select '🟢 Exceeding', from: "aspiration_check_ins[#{aspiration_check_in.id}][official_rating]"
        fill_in "aspiration_check_ins[#{aspiration_check_in.id}][shared_notes]", 
                with: 'Excellent growth trajectory. Continue focusing on leadership development.'
      end
      
      # Submit finalization
      click_button 'Finalize Selected Check-Ins'
      
      # Should see success message
      expect(page).to have_css('.toast-body', text: 'Check-ins finalized successfully', visible: :all)
      
      # Verify aspiration check-in is finalized
      aspiration_check_in.reload
      expect(aspiration_check_in.official_rating).to eq('exceeding')
      expect(aspiration_check_in.shared_notes).to eq('Excellent growth trajectory. Continue focusing on leadership development.')
      expect(aspiration_check_in.official_check_in_completed_at).to be_present
      expect(aspiration_check_in.finalized_by).to eq(manager)
    end
  end
end
