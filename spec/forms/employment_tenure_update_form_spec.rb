require 'rails_helper'

RSpec.describe EmploymentTenureUpdateForm, type: :form do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: company) }
  let(:current_manager) { create(:person) }
  let(:current_manager_teammate) { CompanyTeammate.create!(person: current_manager, organization: company) }
  let(:new_manager) { create(:person) }
  let(:new_manager_teammate) { CompanyTeammate.create!(person: new_manager, organization: company) }
  let(:position_major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:seat) { create(:seat, title: title, seat_needed_by: Date.current + 1.month) }
  
  let(:current_tenure) do
    # Create position and seat first to ensure they match
    pos = position
    seat_obj = create(:seat, title: pos.title, seat_needed_by: Date.current + 10.months)
    
    # Create employment_tenure directly to avoid factory's after(:build) hook overwriting position
    # Ensure manager_teammate is created
    current_manager_teammate
    EmploymentTenure.create!(
      teammate: teammate,
      company: company,
      position: pos,
      manager_teammate: current_manager_teammate,
      seat: seat_obj,
      employment_type: 'full_time',
      started_at: 6.months.ago
    )
  end

  let(:form) { EmploymentTenureUpdateForm.new(current_tenure) }

  describe 'validations' do
    describe 'reason field' do
      it 'validates reason only when major changes are present' do
        # Use the exact same values as current_tenure to ensure no changes
        form.manager_teammate_id = current_tenure.manager_teammate_id
        form.position_id = current_tenure.position_id
        form.employment_type = current_tenure.employment_type
        form.seat_id = current_tenure.seat_id
        form.reason = 'Some reason'
        
        expect(form).not_to be_valid
        expect(form.errors[:reason]).to include('The reason field is only saved when a major change is made (manager, position, employment type, or termination date)')
      end

      it 'allows reason when manager changes' do
        new_manager_teammate
        form.manager_teammate_id = new_manager_teammate.id
        form.position_id = position.id
        form.employment_type = 'full_time'
        form.seat_id = seat.id
        form.reason = 'Manager change'
        
        expect(form).to be_valid
      end

      it 'allows reason when position changes' do
        new_title = create(:title, company: company, position_major_level: position_major_level, external_title: 'New Position Type')
        new_position_level = create(:position_level, position_major_level: position_major_level)
        new_position = create(:position, title: new_title, position_level: new_position_level)
        # Create a seat that matches the new position's title
        new_seat = create(:seat, title: new_title, seat_needed_by: Date.current + 5.months)
        form.manager_teammate_id = current_manager_teammate.id
        form.position_id = new_position.id
        form.employment_type = 'full_time'
        form.seat_id = new_seat.id
        form.reason = 'Position change'
        
        expect(form).to be_valid
      end

      it 'allows reason when employment_type changes' do
        form.manager_teammate_id = current_manager_teammate.id
        form.position_id = position.id
        form.employment_type = 'part_time'
        form.seat_id = seat.id
        form.reason = 'Employment type change'
        
        expect(form).to be_valid
      end

      it 'allows reason when termination_date is provided' do
        form.manager_teammate_id = current_manager_teammate.id
        form.position_id = position.id
        form.employment_type = 'full_time'
        form.seat_id = seat.id
        form.termination_date = Date.current + 1.week
        form.reason = 'Termination'
        
        expect(form).to be_valid
      end

      it 'allows reason with seat change (reason ignored but no error)' do
        new_seat = create(:seat, title: position.title, seat_needed_by: Date.current + 3.months)
        form.manager_teammate_id = current_manager_teammate.id
        form.position_id = position.id
        form.employment_type = 'full_time'
        form.seat_id = new_seat.id
        form.reason = 'Seat change'
        
        expect(form).to be_valid
      end
    end

    describe 'position_id validation' do
      it 'validates position_id exists' do
        form.position_id = 999999
        
        expect(form).not_to be_valid
        expect(form.errors[:position_id]).to be_present
      end
    end

    describe 'manager_teammate_id validation' do
      it 'validates manager_teammate_id exists if provided' do
        form.manager_teammate_id = 999999
        
        expect(form).not_to be_valid
        expect(form.errors[:manager_teammate_id]).to be_present
      end

      it 'allows nil manager_teammate_id' do
        form.manager_teammate_id = nil
        form.position_id = position.id
        form.employment_type = 'full_time'
        
        expect(form).to be_valid
      end
    end

    describe 'seat_id validation' do
      it 'validates seat_id matches position title if provided' do
        other_position_major_level = create(:position_major_level)
        other_title = create(:title, company: company, position_major_level: other_position_major_level)
        other_seat = create(:seat, title: other_title, seat_needed_by: Date.current + 4.months)
        
        form.position_id = position.id
        form.seat_id = other_seat.id
        
        expect(form).not_to be_valid
        expect(form.errors[:seat]).to be_present
      end

      it 'allows nil seat_id' do
        form.position_id = position.id
        form.seat_id = nil
        form.employment_type = 'full_time'
        
        expect(form).to be_valid
      end

      it 'allows empty string seat_id' do
        form.position_id = position.id
        form.seat_id = ''
        form.employment_type = 'full_time'
        
        expect(form).to be_valid
      end
    end

    describe 'termination_date validation' do
      it 'validates termination_date is a valid date if provided' do
        form.termination_date = 'invalid-date'
        
        expect(form).not_to be_valid
        expect(form.errors[:termination_date]).to be_present
      end

      it 'allows nil termination_date' do
        form.position_id = position.id
        form.employment_type = 'full_time'
        form.termination_date = nil
        
        expect(form).to be_valid
      end
    end

    describe 'employment_type validation' do
      it 'validates employment_type inclusion' do
        form.employment_type = 'invalid_type'
        
        expect(form).not_to be_valid
        expect(form.errors[:employment_type]).to be_present
      end

      it 'allows valid employment_type values' do
        form.position_id = position.id
        form.employment_type = 'part_time'
        
        expect(form).to be_valid
      end
    end
  end

  describe '#save' do
    it 'calls UpdateEmploymentTenureService with validated params' do
      creator_teammate = CompanyTeammate.create!(person: create(:person), organization: company)
      form.current_company_teammate = creator_teammate
      form.teammate = teammate
      
      # Validate with params to set up @original_params
      new_manager_teammate
      params = {
        manager_teammate_id: new_manager_teammate.id,
        position_id: position.id,
        employment_type: 'full_time',
        seat_id: seat.id
      }
      form.validate(params)
      
      expect(UpdateEmploymentTenureService).to receive(:call).with(
        teammate: teammate,
        current_tenure: current_tenure,
        params: hash_including(
          manager_teammate_id: new_manager_teammate.id,
          position_id: position.id,
          employment_type: 'full_time',
          seat_id: seat.id
        ),
        created_by: anything
      ).and_return(Result.ok(current_tenure))
      
      form.save
    end

    it 'returns false if validation fails' do
      form.position_id = 999999
      
      expect(form.save).to be false
    end

    it 'clears seat when seat_id is set to nil' do
      creator_teammate = CompanyTeammate.create!(person: create(:person), organization: company)
      form.current_company_teammate = creator_teammate
      form.teammate = teammate
      
      # Ensure current_tenure has a seat
      expect(current_tenure.seat).to be_present
      
      params = {
        manager_teammate_id: current_manager_teammate.id,
        position_id: position.id,
        employment_type: 'full_time',
        seat_id: nil
      }
      
      form.validate(params)
      expect(form).to be_valid
      
      allow(UpdateEmploymentTenureService).to receive(:call).and_return(Result.ok(current_tenure))
      
      form.save
      
      expect(UpdateEmploymentTenureService).to have_received(:call).with(
        teammate: teammate,
        current_tenure: current_tenure,
        params: hash_including(seat_id: nil),
        created_by: creator_teammate
      )
    end

    it 'clears seat when seat_id is set to empty string' do
      creator_teammate = CompanyTeammate.create!(person: create(:person), organization: company)
      form.current_company_teammate = creator_teammate
      form.teammate = teammate
      
      # Ensure current_tenure has a seat
      expect(current_tenure.seat).to be_present
      
      params = {
        manager_teammate_id: current_manager_teammate.id,
        position_id: position.id,
        employment_type: 'full_time',
        seat_id: ''
      }
      
      form.validate(params)
      expect(form).to be_valid
      
      allow(UpdateEmploymentTenureService).to receive(:call).and_return(Result.ok(current_tenure))
      
      form.save
      
      # The form should convert empty string to nil before passing to service
      expect(UpdateEmploymentTenureService).to have_received(:call) do |args|
        expect(args[:params][:seat_id]).to be_nil
      end
    end
  end
end

