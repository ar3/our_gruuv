require 'rails_helper'

RSpec.describe 'MAAP Check-In System End-to-End', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:manager_person) { create(:person, full_name: 'Manager Guy') }
  let!(:manager_teammate) { create(:teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:manager_employment_tenure) do
    create(:employment_tenure,
      teammate: manager_teammate,
      position: position,
      company: organization,
      started_at: 2.years.ago
    )
  end
  let!(:employment_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      position: position,
      company: organization,
      manager: manager_person,
      started_at: 1.year.ago
    )
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(manager_person).to receive(:can_manage_employment?).with(organization).and_return(true)
    allow(manager_person).to receive(:can_manage_employment?).and_return(true)
  end

  describe 'Complete Position Check-In Workflow' do
    it 'creates, completes, and finalizes a position check-in end-to-end' do
      # Step 1: Visit new check-ins page (should auto-create position check-in)
      visit organization_person_check_ins_path(organization, employee_person)
      
      expect(page).to have_content('Check-Ins for John Doe')
      expect(page).to have_content('View Mode: Manager')
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('📝 In Progress')

      # Step 2: Manager completes their assessment
      select '🔵 Praising/Trusting - Consistent strong performance', from: '_position_check_in_manager_rating'
      fill_in '_position_check_in_manager_private_notes', with: 'John is doing excellent work on the frontend features'
      choose '_position_check_in_status_complete'
      
      click_button 'Save All Check-Ins'

      # Verify manager side is completed by checking the page content
      expect(page).to have_content('Check-ins saved successfully.')
      expect(page).to have_content('⏳ Waiting for Employee')

      # Step 3: Switch to employee view
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
      
      visit organization_person_check_ins_path(organization, employee_person)
      
      expect(page).to have_content('View Mode: Employee')
      expect(page).to have_content('✅ Manager has completed their assessment')

      # Step 4: Employee completes their assessment
      select '🟢 Looking to Reward - Exceptional, seeking to increase responsibility', from: '_position_check_in_employee_rating'
      fill_in '_position_check_in_employee_private_notes', with: 'I feel I am exceeding expectations and ready for more responsibility'
      choose '_position_check_in_status_complete'
      
      click_button 'Save All Check-Ins'

      # Verify both sides are completed by checking page content
      expect(page).to have_content('Check-ins saved successfully.')
      expect(page).to have_content('⏳ Ready to Finalize')

      # Step 5: Manager goes to finalization page
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      
      visit organization_person_finalization_path(organization, employee_person)
      
      expect(page).to have_content('Finalize Check-Ins for John Doe')
      expect(page).to have_content('Position Check-In')
      expect(page).to have_content('🔵 Praising/Trusting')
      expect(page).to have_content('🟢 Looking to Reward')

      # Step 6: Manager finalizes the check-in
      check 'finalize_position'
      select '🟢 Looking to Reward - Exceptional, seeking to increase responsibility', from: 'position_official_rating'
      fill_in 'position_shared_notes', with: 'John has demonstrated exceptional performance and is ready for increased responsibility. We will discuss promotion opportunities in the next quarter.'
      
      click_button 'Finalize Selected Check-Ins'

      # Step 7: Verify finalization by checking page content
      expect(page).to have_content('Check-ins finalized successfully. Employee will be notified.')

      # Verify tenure lifecycle
      old_tenure = EmploymentTenure.find(employment_tenure.id)
      expect(old_tenure.ended_at).to eq(Date.current)
      expect(old_tenure.official_position_rating).to eq(3)

      new_tenure = EmploymentTenure.where(teammate: employee_teammate, ended_at: nil).first
      expect(new_tenure).to be_present
      expect(new_tenure.started_at).to eq(Date.current)
      expect(new_tenure.official_position_rating).to be_nil

      # Verify snapshot creation
      snapshot = MaapSnapshot.where(employee: employee_person).last
      expect(snapshot).to be_present
          expect(snapshot.change_type).to eq('position_tenure')
          expect(snapshot.maap_data['position']).to include(
            'manager_id' => manager_person.id,
            'official_rating' => 3,
            'rated_at' => Date.current.to_s
          )
          expect(snapshot.maap_data['position']['position_id']).to be_present

      # Step 8: Employee acknowledges
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
      
      visit organization_person_check_ins_path(organization, employee_person)
      
      expect(page).to have_content('⚠️ Your manager has finalized check-ins.')
      
      click_link 'Review and Acknowledge'
      
      expect(page).to have_content('Finalize Check-Ins for John Doe')
      expect(page).to have_content('🟢 Looking to Reward')
      expect(page).to have_content('John has demonstrated exceptional performance')
      
      click_button 'Acknowledge Finalized Check-Ins'

      # Verify acknowledgement
      expect(page).to have_content('You have acknowledged the finalized check-ins.')
      
      # Verify in database
      snapshot = MaapSnapshot.where(employee: employee_person).last
      expect(snapshot.acknowledged?).to be true
      expect(snapshot.employee_acknowledged_at).to be_present
    end

    it 'handles mutual blindness correctly' do
      # Create position check-in
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      
      # Manager completes first
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      
      visit organization_person_check_ins_path(organization, employee_person)
      
      select '🔵 Praising/Trusting - Consistent strong performance', from: 'position_check_in_manager_rating'
      fill_in 'position_check_in_manager_private_notes', with: 'Manager notes'
      choose 'position_check_in_status_complete'
      click_button 'Save All Check-Ins'

      # Switch to employee view
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
      
      visit organization_person_check_ins_path(organization, employee_person)
      
      # Employee should NOT see manager's rating or notes
      expect(page).to have_content('✅ Manager has completed their assessment')
      expect(page).not_to have_content('🔵 Praising/Trusting')
      expect(page).not_to have_content('Manager notes')
      
      # Employee completes
      select '🟡 Actively Coaching - Mostly meeting expectations... Working on specific improvements', from: 'position_check_in_employee_rating'
      fill_in 'position_check_in_employee_private_notes', with: 'Employee notes'
      choose 'position_check_in_status_complete'
      click_button 'Save All Check-Ins'

      # Switch back to manager view
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      
      visit organization_person_check_ins_path(organization, employee_person)
      
      # Manager should NOT see employee's rating or notes
      expect(page).to have_content('✅ John Doe has completed their perspective (hidden until you complete yours)')
      expect(page).not_to have_content('🟡 Actively Coaching')
      expect(page).not_to have_content('Employee notes')

      # Both complete, now ready for finalization
      position_check_in.reload
      expect(position_check_in.ready_for_finalization?).to be true
    end

    it 'handles draft vs ready status correctly' do
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      
      # Manager saves as draft
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      
      visit organization_person_check_ins_path(organization, employee_person)
      
      select '🔵 Praising/Trusting - Consistent strong performance', from: 'position_check_in_manager_rating'
      fill_in 'position_check_in_manager_private_notes', with: 'Draft notes'
      choose 'position_check_in_status_draft'
      click_button 'Save All Check-Ins'

      # Should not be completed
      position_check_in.reload
      expect(position_check_in.manager_completed?).to be false
      expect(position_check_in.manager_rating).to eq(2)
      expect(position_check_in.manager_private_notes).to eq('Draft notes')

      # Now mark as ready
      visit organization_person_check_ins_path(organization, employee_person)
      choose 'position_check_in_status_complete'
      click_button 'Save All Check-Ins'

      # Should now be completed
      position_check_in.reload
      expect(position_check_in.manager_completed?).to be true
    end

    it 'prevents multiple open check-ins per teammate' do
      # Create first check-in
      position_check_in1 = PositionCheckIn.find_or_create_open_for(employee_teammate)
      expect(position_check_in1).to be_present

      # Try to create second check-in
      expect {
        PositionCheckIn.create!(
          teammate: employee_teammate,
          employment_tenure: employment_tenure,
          check_in_started_on: Date.current
        )
      }.to raise_error(ActiveRecord::RecordInvalid, /Only one open position check-in allowed per teammate/)

      # Verify only one exists
      open_check_ins = PositionCheckIn.where(teammate: employee_teammate).open
      expect(open_check_ins.count).to eq(1)
      expect(open_check_ins.first).to eq(position_check_in1)
    end

    it 'handles finalization with different ratings' do
      # Create and complete check-in with different perspectives
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      
      # Employee thinks they're exceeding
      position_check_in.update!(
        employee_rating: 3,
        employee_private_notes: 'I feel I am exceeding expectations',
        employee_completed_at: Time.current
      )
      
      # Manager thinks they're meeting
      position_check_in.update!(
        manager_rating: 2,
        manager_private_notes: 'Meeting expectations well',
        manager_completed_at: Time.current,
        manager_completed_by: manager_person
      )

      # Manager finalizes with their assessment
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      
      visit organization_person_finalization_path(organization, employee_person)
      
      check 'finalize_position'
      select '🔵 Praising/Trusting - Consistent strong performance', from: 'position_official_rating'
      fill_in 'position_shared_notes', with: 'Good performance, continue current trajectory'
      
      click_button 'Finalize Selected Check-Ins'

      # Verify finalization uses manager's rating
      position_check_in.reload
      expect(position_check_in.official_rating).to eq(2)
      expect(position_check_in.shared_notes).to eq('Good performance, continue current trajectory')
    end
  end

  describe 'Check-in Status Badges' do
    it 'displays correct status badges throughout workflow' do
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      
      # Initial state
      visit organization_person_check_ins_path(organization, employee_person)
      expect(page).to have_content('📝 In Progress')

      # Employee completed
      position_check_in.update!(
        employee_rating: 2,
        employee_completed_at: Time.current
      )
      
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
      visit organization_person_check_ins_path(organization, employee_person)
      expect(page).to have_content('⏳ Waiting for Manager')

      # Manager completed
      position_check_in.update!(
        manager_rating: 2,
        manager_completed_at: Time.current,
        manager_completed_by: manager_person
      )
      
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      visit organization_person_check_ins_path(organization, employee_person)
      expect(page).to have_content('⏳ Ready to Finalize')

      # Finalized
      position_check_in.update!(
        official_rating: 2,
        official_check_in_completed_at: Time.current,
        finalized_by: manager_person
      )
      
      visit organization_person_check_ins_path(organization, employee_person)
      expect(page).to have_content('✅ Complete')
    end
  end

  describe 'Error Handling' do
    it 'handles finalization without ready check-ins' do
      # Try to finalize when no check-ins are ready
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      
      visit organization_person_finalization_path(organization, employee_person)
      
      expect(page).to have_content('Finalize Check-Ins for John Doe')
      expect(page).not_to have_content('Position Check-In')
      
      # Should not be able to finalize anything
      expect(page).not_to have_button('Finalize Selected Check-Ins')
    end

    it 'handles unauthorized access' do
      # Non-manager tries to access finalization
      non_manager = create(:person, full_name: 'Regular Employee')
      create(:teammate, person: non_manager, organization: organization, can_manage_employment: false)
      
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(non_manager)
      allow(non_manager).to receive(:can_manage_employment?).and_return(false)

      # Should redirect or show error
      expect {
        visit organization_person_finalization_path(organization, employee_person)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
