require 'rails_helper'

RSpec.describe 'Organizations::Teammates::Position', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization, can_manage_employment: true) }
  let(:employee_person) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let(:manager) { create(:person) }
  let(:new_manager) { create(:person) }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let(:new_position_type) { create(:position_type, organization: organization, position_major_level: position_major_level, external_title: 'New Position Type') }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:new_position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:new_position) { create(:position, position_type: new_position_type, position_level: new_position_level) }
  
  let(:current_tenure) do
    # Create position and seat first to ensure they match
    pos = position
    seat_obj = create(:seat, position_type: pos.position_type, seat_needed_by: Date.current + 10.months)
    
    # Create employment_tenure directly to avoid factory's after(:build) hook overwriting position
    EmploymentTenure.create!(
      teammate: employee_teammate,
      company: organization,
      position: pos,
      manager: manager,
      seat: seat_obj,
      employment_type: 'full_time',
      started_at: 6.months.ago
    )
  end

  before do
    sign_in_as_teammate_for_request(person, organization)
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
      
      # Create an available seat
      available_seat = create(:seat, position_type: position.position_type, seat_needed_by: Date.current + 12.months)
      
      get organization_teammate_position_path(organization, employee_teammate)
      
      expect(assigns(:seats)).to include(current_tenure.seat) # Current tenure's seat
      expect(assigns(:seats)).to include(available_seat) # Available seat
      expect(assigns(:seats)).not_to include(filled_seat) # Filled seat excluded
    end

    it 'includes current tenure seat even if it is the only one' do
      get organization_teammate_position_path(organization, employee_teammate)
      
      expect(assigns(:seats)).to include(current_tenure.seat)
    end
  end

  describe 'PATCH /organizations/:id/teammates/:id/position' do
    before { current_tenure }

    context 'when user has can_manage_employment permission' do
      let(:teammate) { create(:teammate, person: person, organization: organization, can_manage_employment: true) }

      it 'authorizes with can_manage_employment permission' do
        patch organization_teammate_position_path(organization, employee_teammate), params: {
          employment_tenure: {
            manager_id: new_manager.id,
            position_id: position.id,
            employment_type: 'full_time',
            seat_id: current_tenure.seat_id
          }
        }
        
        expect(response).to have_http_status(:redirect)
      end

      it 'updates tenure on manager change' do
        expect {
          patch organization_teammate_position_path(organization, employee_teammate), params: {
            employment_tenure: {
              manager_id: new_manager.id,
              position_id: position.id,
              employment_type: 'full_time',
              seat_id: current_tenure.seat_id
            }
          }
        }.to change { current_tenure.reload.ended_at }.from(nil)
        
        new_tenure = EmploymentTenure.where(teammate: employee_teammate, company: organization).order(:created_at).last
        expect(new_tenure.manager).to eq(new_manager)
      end

      it 'updates tenure on position change' do
        seat_for_new_position = create(:seat, position_type: new_position_type, seat_needed_by: Date.current + 16.months)
        
        expect {
          patch organization_teammate_position_path(organization, employee_teammate), params: {
            employment_tenure: {
              manager_id: manager.id,
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
            manager_id: manager.id,
            position_id: position.id,
            employment_type: 'full_time',
            seat_id: current_tenure.seat_id,
            termination_date: termination_date
          }
        }
        
        expect(current_tenure.reload.ended_at).to eq(termination_date)
      end

      it 'creates maap_snapshot when manager changes' do
        expect {
          patch organization_teammate_position_path(organization, employee_teammate), params: {
            employment_tenure: {
              manager_id: new_manager.id,
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
              manager_id: manager.id,
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
              manager_id: manager.id,
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
              manager_id: manager.id,
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
        patch organization_teammate_position_path(organization, employee_teammate), params: {
          employment_tenure: {
            manager_id: new_manager.id,
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
      let(:teammate) { create(:teammate, person: person, organization: organization, can_manage_employment: false) }

      it 'returns 403 without permission' do
        patch organization_teammate_position_path(organization, employee_teammate), params: {
          employment_tenure: {
            manager_id: new_manager.id,
            position_id: position.id,
            employment_type: 'full_time',
            seat_id: current_tenure.seat_id
          }
        }
        
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end

