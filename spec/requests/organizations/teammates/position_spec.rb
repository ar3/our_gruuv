require 'rails_helper'

RSpec.describe 'Organizations::Teammates::Position', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, type: 'CompanyTeammate', person: person, organization: organization, can_manage_employment: true) }
  let(:employee_person) { create(:person) }
  let(:employee_teammate) { create(:teammate, type: 'CompanyTeammate', person: employee_person, organization: organization) }
  let(:manager) { create(:person) }
  let(:manager_teammate) do
    teammate = create(:teammate, type: 'CompanyTeammate', person: manager, organization: organization)
    # Ensure it's actually a CompanyTeammate instance
    CompanyTeammate.find(teammate.id)
  end
  let(:new_manager) { create(:person) }
  let(:new_manager_teammate) { create(:teammate, type: 'CompanyTeammate', person: new_manager, organization: organization) }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let(:new_position_type) { create(:position_type, organization: organization, position_major_level: position_major_level, external_title: 'New Position Type') }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:new_position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:new_position) { create(:position, position_type: new_position_type, position_level: new_position_level) }
  
  # Create employment tenure for the teammate (manager) so they have an org to check permissions against
  let!(:teammate_employment_tenure) do
    pos = position
    create(:employment_tenure,
      teammate: teammate,
      company: organization,
      position: pos,
      employment_type: 'full_time',
      started_at: 1.year.ago
    )
  end

  let(:current_tenure) do
    # Create position and seat first to ensure they match
    pos = position
    seat_obj = create(:seat, position_type: pos.position_type, seat_needed_by: Date.current + 10.months)
    
    # Create employment_tenure directly to avoid factory's after(:build) hook overwriting position
    # Ensure manager_teammate is created and is a CompanyTeammate instance
    manager_ct = manager_teammate
    manager_ct = CompanyTeammate.find(manager_ct.id) unless manager_ct.is_a?(CompanyTeammate)
    EmploymentTenure.create!(
      teammate: employee_teammate,
      company: organization,
      position: pos,
      manager_teammate: manager_ct,
      seat: seat_obj,
      employment_type: 'full_time',
      started_at: 6.months.ago
    )
  end

  before do
    # Ensure teammate exists with correct permissions and type before signing in
    # Use a method to get the teammate so it works with context overrides
    teammate_instance = teammate # This ensures the teammate is created
    # Ensure it's actually a CompanyTeammate instance
    teammate_instance.reload
    unless teammate_instance.is_a?(CompanyTeammate)
      # Fix the type if needed
      teammate_instance.update_column(:type, 'CompanyTeammate')
      teammate_instance = Teammate.find(teammate_instance.id) # Reload as CompanyTeammate
    end

    # Set first_employed_at for employed? check in policies
    teammate_instance.update!(first_employed_at: 1.year.ago) unless teammate_instance.first_employed_at

    # Stub current_company_teammate for both ApplicationController and OrganizationNamespaceBaseController
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(teammate_instance)
    allow_any_instance_of(Organizations::OrganizationNamespaceBaseController).to receive(:current_company_teammate).and_return(teammate_instance)
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(teammate_instance.person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(teammate_instance.organization)
  end

  describe 'GET /organizations/:id/teammates/:id/position' do
    before { current_tenure }

    it 'returns http success' do
      get organization_teammate_position_path(organization, employee_teammate)
      expect(response).to have_http_status(:success)
    end

    it 'loads only available seats (not associated with active tenures)' do
      # Create another seat that's filled
      filled_seat = create(:seat, position_type: position.position_type, seat_needed_by: Date.current + 11.months)
      other_teammate = create(:teammate, person: create(:person), organization: organization)
      EmploymentTenure.create!(
        teammate: other_teammate,
        company: organization,
        position: position,
        seat: filled_seat,
        started_at: 1.month.ago
      )
      
      # Create an available seat (ensure it's in open or filled state)
      available_seat = create(:seat, position_type: position.position_type, seat_needed_by: Date.current + 12.months, state: :open)
      
      get organization_teammate_position_path(organization, employee_teammate)
      
      expect(assigns(:seats)).to include(current_tenure.seat) # Current tenure's seat
      expect(assigns(:seats)).to include(available_seat) # Available seat
      expect(assigns(:seats)).not_to include(filled_seat) # Filled seat excluded
    end

    it 'includes current tenure seat even if it is the only one' do
      get organization_teammate_position_path(organization, employee_teammate)
      
      expect(assigns(:seats)).to include(current_tenure.seat)
    end

    it 'sets @person for view switcher' do
      get organization_teammate_position_path(organization, employee_teammate)
      expect(assigns(:person)).to eq(employee_person)
    end

    it 'loads only distinct active managers who are active company teammates, ordered by last_name, first_name' do
      # Create additional managers
      manager1 = create(:person, first_name: 'Alice', last_name: 'Zebra')
      manager2 = create(:person, first_name: 'Bob', last_name: 'Alpha')
      manager3 = create(:person, first_name: 'Charlie', last_name: 'Beta')
      
      # Create teammates for managers
      manager1_teammate = create(:teammate, type: 'CompanyTeammate', person: manager1, organization: organization)
      manager2_teammate = create(:teammate, type: 'CompanyTeammate', person: manager2, organization: organization)
      manager3_teammate = create(:teammate, type: 'CompanyTeammate', person: manager3, organization: organization)
      
      # Create active employment tenures for managers (so they are active teammates)
      create(:employment_tenure, teammate: manager1_teammate, company: organization, position: position, started_at: 1.year.ago)
      create(:employment_tenure, teammate: manager2_teammate, company: organization, position: position, started_at: 1.year.ago)
      create(:employment_tenure, teammate: manager3_teammate, company: organization, position: position, started_at: 1.year.ago)
      
      # Create active employment tenures where these people are managers
      # Use different employees to avoid overlapping tenures
      other_employee1 = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: organization)
      other_employee2 = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: organization)
      other_employee3 = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: organization)
      create(:employment_tenure, teammate: other_employee1, company: organization, position: position, manager: manager1, started_at: 6.months.ago)
      create(:employment_tenure, teammate: other_employee2, company: organization, position: position, manager: manager2, started_at: 5.months.ago)
      create(:employment_tenure, teammate: other_employee3, company: organization, position: position, manager: manager3, started_at: 4.months.ago)
      
      # Create an inactive manager (should not appear)
      inactive_manager = create(:person, first_name: 'Inactive', last_name: 'Manager')
      inactive_manager_teammate = create(:teammate, type: 'CompanyTeammate', person: inactive_manager, organization: organization)
      create(:employment_tenure, teammate: inactive_manager_teammate, company: organization, position: position, started_at: 2.years.ago, ended_at: 1.year.ago)
      other_employee4 = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: organization)
      create(:employment_tenure, teammate: other_employee4, company: organization, position: position, manager: inactive_manager, started_at: 3.months.ago, ended_at: 1.month.ago)
      
      # Create a manager who is not an active teammate (should not appear)
      non_teammate_manager = create(:person, first_name: 'Non', last_name: 'Teammate')
      other_employee5 = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: organization)
      create(:employment_tenure, teammate: other_employee5, company: organization, position: position, manager: non_teammate_manager, started_at: 2.months.ago)
      
      get organization_teammate_position_path(organization, employee_teammate)
      
      managers = assigns(:managers)
      expect(managers).to be_present
      # Should include active managers who are active teammates
      expect(managers).to include(manager1, manager2, manager3)
      # Should not include inactive manager
      expect(managers).not_to include(inactive_manager)
      # Should not include non-teammate manager
      expect(managers).not_to include(non_teammate_manager)
      # Should be ordered by last_name, first_name
      expect(managers.map(&:last_name)).to eq(['Alpha', 'Beta', 'Zebra'])
      # Should be distinct
      expect(managers.uniq.size).to eq(managers.size)
    end

    it 'loads all active employees excluding managers and current person' do
      # Create a non-manager employee
      non_manager_person = create(:person, first_name: 'NonManager', last_name: 'Employee')
      non_manager_teammate = create(:teammate, type: 'CompanyTeammate', person: non_manager_person, organization: organization)
      create(:employment_tenure, teammate: non_manager_teammate, company: organization, position: position, started_at: 3.months.ago)
      
      # Create another manager (already tested above, but needed for this test)
      manager1 = create(:person, first_name: 'Alice', last_name: 'Zebra')
      manager1_teammate = create(:teammate, type: 'CompanyTeammate', person: manager1, organization: organization)
      create(:employment_tenure, teammate: manager1_teammate, company: organization, position: position, started_at: 1.year.ago)
      other_employee = create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: organization)
      create(:employment_tenure, teammate: other_employee, company: organization, position: position, manager: manager1, started_at: 6.months.ago)
      
      get organization_teammate_position_path(organization, employee_teammate)
      
      all_employees = assigns(:all_employees)
      expect(all_employees).to be_present
      # Should include non-manager employees
      expect(all_employees).to include(non_manager_person)
      # Should not include managers
      expect(all_employees).not_to include(manager1)
      # Should not include the current person being edited
      expect(all_employees).not_to include(employee_person)
      # Should be ordered by last_name, first_name
      expect(all_employees.map(&:last_name)).to eq(all_employees.map(&:last_name).sort)
    end
  end

  describe 'PATCH /organizations/:id/teammates/:id/position' do
    before { current_tenure }

    context 'when user has can_manage_employment permission' do
      let(:teammate) { create(:teammate, type: 'CompanyTeammate', person: person, organization: organization, can_manage_employment: true) }

      it 'authorizes with can_manage_employment permission' do
        new_manager_teammate
        patch organization_teammate_position_path(organization, employee_teammate), params: {
          employment_tenure: {
            manager_teammate_id: new_manager_teammate.id,
            position_id: position.id,
            employment_type: 'full_time',
            seat_id: current_tenure.seat_id
          }
        }
        
        expect(response).to have_http_status(:redirect)
      end

      it 'updates tenure on manager change' do
        new_manager_teammate
        # Debug: Check initial state
        puts "Current tenure manager_teammate_id: #{current_tenure.manager_teammate_id.inspect}"
        puts "New manager teammate id: #{new_manager_teammate.id.inspect}"
        puts "Managers are different: #{current_tenure.manager_teammate_id != new_manager_teammate.id}"
        
        patch organization_teammate_position_path(organization, employee_teammate), params: {
          employment_tenure: {
            manager_teammate_id: new_manager_teammate.id,
            position_id: position.id,
            employment_type: 'full_time',
            seat_id: current_tenure.seat_id
          }
        }
        
        # Debug: Check response status and form errors
        puts "Response status: #{response.status}"
        if assigns(:form)
          puts "Form errors: #{assigns(:form).errors.full_messages}" if assigns(:form).errors.any?
          puts "Form valid?: #{assigns(:form).valid?}"
          puts "Form manager_teammate_id: #{assigns(:form).manager_teammate_id.inspect}" if assigns(:form).respond_to?(:manager_teammate_id)
        end
        puts "Current tenure ended_at after: #{current_tenure.reload.ended_at.inspect}"
        puts "All tenures: #{EmploymentTenure.where(teammate: employee_teammate, company: organization).pluck(:id, :manager_teammate_id, :ended_at).inspect}"
        
        expect(response).to have_http_status(:redirect)
        expect(current_tenure.reload.ended_at).not_to be_nil
        new_tenure = EmploymentTenure.where(teammate: employee_teammate, company: organization).order(:created_at).last
        expect(new_tenure.manager_teammate_id).to eq(new_manager_teammate.id)
      end

      it 'updates tenure on position change' do
        seat_for_new_position = create(:seat, position_type: new_position_type, seat_needed_by: Date.current + 16.months)
        
        expect {
          patch organization_teammate_position_path(organization, employee_teammate), params: {
            employment_tenure: {
              manager_teammate_id: manager_teammate.id,
              position_id: new_position.id,
              employment_type: 'full_time',
              seat_id: seat_for_new_position.id
            }
          }
        }.to change { current_tenure.reload.ended_at }.from(nil)
        
        new_tenure = EmploymentTenure.where(teammate: employee_teammate, company: organization).order(:created_at).last
        expect(new_tenure.position).to eq(new_position)
      end

      it 'updates tenure on termination date' do
        termination_date = Date.current + 1.week
        
        patch organization_teammate_position_path(organization, employee_teammate), params: {
          employment_tenure: {
            manager_teammate_id: manager_teammate.id,
            position_id: position.id,
            employment_type: 'full_time',
            seat_id: current_tenure.seat_id,
            termination_date: termination_date
          }
        }
        
        # ended_at is stored as DateTime, so compare dates
        expect(current_tenure.reload.ended_at.to_date).to eq(termination_date)
      end

      it 'creates maap_snapshot when manager changes' do
        new_manager_teammate
        expect {
          patch organization_teammate_position_path(organization, employee_teammate), params: {
            employment_tenure: {
              manager_teammate_id: new_manager_teammate.id,
              position_id: position.id,
              employment_type: 'full_time',
              seat_id: current_tenure.seat_id,
              reason: 'Manager change'
            }
          }
        }.to change { MaapSnapshot.count }.by(1)
        
        snapshot = MaapSnapshot.last
        expect(snapshot.change_type).to eq('position_tenure')
        expect(snapshot.employee).to eq(employee_person)
        expect(snapshot.reason).to eq('Manager change')
      end

      it 'creates maap_snapshot when position changes' do
        seat_for_new_position = create(:seat, position_type: new_position_type, seat_needed_by: Date.current + 14.months)
        
        expect {
          patch organization_teammate_position_path(organization, employee_teammate), params: {
            employment_tenure: {
              manager_teammate_id: manager_teammate.id,
              position_id: new_position.id,
              employment_type: 'full_time',
              seat_id: seat_for_new_position.id
            }
          }
        }.to change { MaapSnapshot.count }.by(1)
      end

      it 'creates maap_snapshot when termination_date is provided' do
        termination_date = Date.current + 1.week
        
        expect {
          patch organization_teammate_position_path(organization, employee_teammate), params: {
            employment_tenure: {
              manager_teammate_id: manager_teammate.id,
              position_id: position.id,
              employment_type: 'full_time',
              seat_id: current_tenure.seat_id,
              termination_date: termination_date
            }
          }
        }.to change { MaapSnapshot.count }.by(1)
        
        snapshot = MaapSnapshot.last
        expect(snapshot.effective_date).to eq(termination_date)
      end

      it 'does not create maap_snapshot when only seat changes' do
        new_seat = create(:seat, position_type: position.position_type, seat_needed_by: Date.current + 15.months)
        
        expect {
          patch organization_teammate_position_path(organization, employee_teammate), params: {
            employment_tenure: {
              manager_teammate_id: manager_teammate.id,
              position_id: position.id,
              employment_type: 'full_time',
              seat_id: new_seat.id
            }
          }
        }.not_to change { MaapSnapshot.count }
      end

      it 'handles validation errors' do
        patch organization_teammate_position_path(organization, employee_teammate), params: {
          employment_tenure: {
            position_id: 999999, # Invalid position
            employment_type: 'full_time'
          }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:show)
      end

      it 'redirects with success message on successful update' do
        new_manager_teammate
        patch organization_teammate_position_path(organization, employee_teammate), params: {
          employment_tenure: {
            manager_teammate_id: new_manager_teammate.id,
            position_id: position.id,
            employment_type: 'full_time',
            seat_id: current_tenure.seat_id
          }
        }
        
        expect(response).to redirect_to(organization_teammate_position_path(organization, employee_teammate))
        expect(flash[:notice]).to eq('Position information was successfully updated.')
      end
    end

    context 'when user does not have can_manage_employment permission' do
      let(:teammate) { create(:teammate, type: 'CompanyTeammate', person: person, organization: organization, can_manage_employment: false) }
      
      # Create employment tenure for the teammate so they have an org, but without permission
      let!(:teammate_employment_tenure) do
        pos = position
        create(:employment_tenure,
          teammate: teammate,
          company: organization,
          position: pos,
          employment_type: 'full_time',
          started_at: 1.year.ago
        )
      end

      it 'returns 403 without permission' do
        new_manager_teammate
        patch organization_teammate_position_path(organization, employee_teammate), params: {
          employment_tenure: {
            manager_teammate_id: new_manager_teammate.id,
            position_id: position.id,
            employment_type: 'full_time',
            seat_id: current_tenure.seat_id
          }
        }
        
        # Authorization failures redirect (302) with flash message, not 403
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to match(/permission|don't have permission/i)
      end
    end
  end

  describe 'POST /organizations/:id/teammates/:id/position/create_employment' do
    let(:teammate_without_employment) { create(:teammate, type: 'CompanyTeammate', person: create(:person), organization: organization) }
    
    context 'when user has can_manage_employment permission' do
      let(:teammate) { create(:teammate, type: 'CompanyTeammate', person: person, organization: organization, can_manage_employment: true) }

      context 'starting new employment (no previous tenures)' do
        it 'creates a new employment tenure' do
          post create_employment_organization_teammate_position_path(organization, teammate_without_employment), params: {
            employment_tenure: {
              position_id: position.id,
              manager_teammate_id: manager_teammate.id,
              started_at: Date.current
            }
          }
          
          expect(response).to have_http_status(:redirect)
          expect(flash[:notice]).to eq('Employment was successfully started.')
          
          new_tenure = EmploymentTenure.where(teammate: teammate_without_employment, company: organization).last
          expect(new_tenure).to be_present
          expect(new_tenure.position).to eq(position)
          expect(new_tenure.manager_teammate_id).to eq(manager_teammate.id)
          expect(new_tenure.started_at.to_date).to eq(Date.current)
          expect(new_tenure.employment_type).to eq('full_time')
          expect(new_tenure.active?).to be true
        end

        it 'creates employment without manager' do
          post create_employment_organization_teammate_position_path(organization, teammate_without_employment), params: {
            employment_tenure: {
              position_id: position.id,
              started_at: Date.current
            }
          }
          
          expect(response).to have_http_status(:redirect)
          new_tenure = EmploymentTenure.where(teammate: teammate_without_employment, company: organization).last
          expect(new_tenure.manager_teammate).to be_nil
        end
      end

      context 'restarting employment (with inactive tenures)' do
        let!(:inactive_tenure) do
          EmploymentTenure.create!(
            teammate: teammate_without_employment,
            company: organization,
            position: position,
            started_at: 2.years.ago,
            ended_at: 1.year.ago
          )
        end

        it 'creates a new employment tenure after inactive tenure' do
          restart_date = 6.months.ago.to_date
          post create_employment_organization_teammate_position_path(organization, teammate_without_employment), params: {
            employment_tenure: {
              position_id: position.id,
              manager_teammate_id: manager_teammate.id,
              started_at: restart_date
            }
          }
          
          expect(response).to have_http_status(:redirect)
          new_tenure = EmploymentTenure.where(teammate: teammate_without_employment, company: organization).order(:created_at).last
          expect(new_tenure.started_at.to_date).to eq(restart_date)
          expect(new_tenure.active?).to be true
        end

        it 'adjusts start date if before last inactive end date' do
          # Try to start before the inactive tenure ended
          early_date = (inactive_tenure.ended_at - 1.day).to_date
          post create_employment_organization_teammate_position_path(organization, teammate_without_employment), params: {
            employment_tenure: {
              position_id: position.id,
              started_at: early_date
            }
          }
          
          expect(response).to have_http_status(:redirect)
          new_tenure = EmploymentTenure.where(teammate: teammate_without_employment, company: organization).order(:created_at).last
          # Should be adjusted to 1 minute after the inactive end date
          expect(new_tenure.started_at).to be > inactive_tenure.ended_at
          expect(new_tenure.started_at).to be_within(2.minutes).of(inactive_tenure.ended_at + 1.minute)
        end
      end

      it 'requires position_id' do
        post create_employment_organization_teammate_position_path(organization, teammate_without_employment), params: {
          employment_tenure: {
            started_at: Date.current
          }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:show)
      end

      it 'requires started_at' do
        post create_employment_organization_teammate_position_path(organization, teammate_without_employment), params: {
          employment_tenure: {
            position_id: position.id
          }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:show)
      end

      it 'handles invalid position_id' do
        post create_employment_organization_teammate_position_path(organization, teammate_without_employment), params: {
          employment_tenure: {
            position_id: 999999,
            started_at: Date.current
          }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:show)
      end

      it 'loads positions grouped by department' do
        department = create(:organization, :department, parent: organization)
        dept_position_type = create(:position_type, organization: department, position_major_level: position_major_level)
        dept_position = create(:position, position_type: dept_position_type, position_level: position_level)
        
        get organization_teammate_position_path(organization, teammate_without_employment)
        
        positions_by_dept = assigns(:positions_by_department)
        expect(positions_by_dept).to be_present
        # Check that both company and department are in the keys (using IDs for comparison)
        org_ids = positions_by_dept.keys.map(&:id)
        expect(org_ids).to include(organization.id, department.id)
        # Find the actual objects in the hash
        company_key = positions_by_dept.keys.find { |k| k.id == organization.id }
        dept_key = positions_by_dept.keys.find { |k| k.id == department.id }
        expect(positions_by_dept[company_key]).to include(position)
        expect(positions_by_dept[dept_key]).to include(dept_position)
      end
    end

    context 'when user does not have can_manage_employment permission' do
      let(:teammate) { create(:teammate, type: 'CompanyTeammate', person: person, organization: organization, can_manage_employment: false) }
      
      # Create employment tenure for the teammate so they have an org, but without permission
      let!(:teammate_employment_tenure) do
        pos = position
        create(:employment_tenure,
          teammate: teammate,
          company: organization,
          position: pos,
          employment_type: 'full_time',
          started_at: 1.year.ago
        )
      end

      it 'returns 403 without permission' do
        post create_employment_organization_teammate_position_path(organization, teammate_without_employment), params: {
          employment_tenure: {
            position_id: position.id,
            started_at: Date.current
          }
        }
        
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to match(/permission|don't have permission/i)
      end
    end
  end
end

