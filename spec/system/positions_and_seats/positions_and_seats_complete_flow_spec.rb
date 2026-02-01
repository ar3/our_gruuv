require 'rails_helper'

RSpec.describe 'Positions and Seats Complete Flow', type: :system do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person, full_name: 'Manager') }
  let!(:teammate) { CompanyTeammate.create!(person: person, organization: company, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  # Create teammate but NO employment - this makes them a "potential employee"
  let!(:employee_teammate) { CompanyTeammate.create!(person: employee_person, organization: company) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:title) { create(:title, company: company, external_title: 'Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }

  before do
    sign_in_as(person, company)
  end

  describe 'CRUD all components of a position' do
    xit 'creates position type, position level, position, and seat' do # SKIPPED: For now
      # Create position type
      visit new_title_path
      fill_in 'title_external_title', with: 'Senior Engineer'
      select position_major_level.set_name, from: 'title_position_major_level_id'
      click_button 'Create Position Type'
      
      title = Title.last
      expect(title.external_title).to eq('Senior Engineer')
      
      # Create position level directly (no separate route for this)
      position_level = create(:position_level, position_major_level: position_major_level, level: '2.1')
      expect(position_level.level).to eq('2.1')
      
      # Create position
      visit new_organization_position_path(company)
      select title.external_title, from: 'title_select'
      select position_level.level, from: 'position_level_select'
      click_button 'Create Position'
      
      position = Position.last
      expect(position.title).to eq(title)
      expect(position.position_level).to eq(position_level)
      
      # Create seat
      visit new_organization_seat_path(company)
      select title.external_title, from: 'seat_title_id'
      fill_in 'seat_seat_needed_by', with: (Date.current + 3.months).to_s
      click_button 'Create Seat'
      
      seat = Seat.last
      expect(seat.title).to eq(title)
      expect(seat.seat_needed_by).to be_present
    end
  end

  describe 'Assign employment tenure of position to employee' do
    let!(:position) { create(:position, title: title, position_level: position_level) }
    let!(:seat) { create(:seat, title: title) }

    xit 'assigns employment tenure and creates maap_snapshot' do # DELETED: Employment tenure assignment flow
      # Assign employment tenure
      visit new_organization_employment_management_path(company)
      
      # Find the "Create Employment" button in the table row for employee_person
      employee_row = find('tr', text: employee_person.display_name)
      within(employee_row) do
        create_employment_link = find('a.btn-success', text: 'Create Employment')
        page.execute_script("window.confirm = function() { return true; }")
        create_employment_link.click
      end
      
      # Wait for form to load (controller renders :new again with person pre-selected)
      expect(page).to have_content('Employment Details', wait: 5)
      
      # Fill out employment form
      select position.display_name, from: 'employment_tenure[position_id]'
      select seat.display_name, from: 'employment_tenure[seat_id]' if page.has_select?('employment_tenure[seat_id]')
      fill_in 'employment_tenure[started_at]', with: Date.current
      click_button 'Create Employment'
      
      # Verify employment tenure was created
      employment_tenure = EmploymentTenure.last
      expect(employment_tenure.teammate).to eq(employee_teammate)
      expect(employment_tenure.position).to eq(position)
      expect(employment_tenure.seat).to eq(seat)
      
      # Verify maap_snapshot was created
      snapshot = MaapSnapshot.find_by(employee: employee_person, change_type: 'position_tenure')
      expect(snapshot).to be_present
      expect(snapshot.maap_data['employment_tenure']).to be_present
    end

    xit 'creates maap_snapshot when changing employment tenure' do # DELETED: Employment tenure change flow
      # Create existing employment tenure - ensure seat matches position's title
      existing_tenure = create(:employment_tenure,
        teammate: employee_teammate,
        position: position,
        seat: seat, # seat already matches position.title from let! block
        company: company,
        started_at: 1.year.ago
      )
      
      # Change employment tenure
      visit edit_employment_tenure_path(existing_tenure)
      
      new_position = create(:position, title: title, position_level: position_level)
      select new_position.external_title, from: 'employment_tenure_position_id'
      
      click_button 'Update Employment Tenure'
      
      # Verify new maap_snapshot was created
      snapshots = MaapSnapshot.where(employee: employee_person, change_type: 'position_tenure').order(created_at: :desc)
      expect(snapshots.count).to be >= 1
      expect(snapshots.first.maap_data['employment_tenure']).to be_present
    end
  end
end

