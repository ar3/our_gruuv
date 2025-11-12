require 'rails_helper'

RSpec.describe Seats::CreateMissingEmployeeSeatsService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:service) { described_class.new(organization) }

  describe '#call' do
    context 'when employees have no seats' do
      it 'creates seats for employees without seats' do
        employee1 = create(:person)
        employee1_teammate = create(:teammate, person: employee1, organization: organization, first_employed_at: 1.year.ago)
        tenure = create(:employment_tenure, teammate: employee1_teammate, company: organization, position: position, started_at: 1.year.ago, seat: nil)
        
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(1)
        expect(result[:errors]).to be_empty
        
        tenure.reload
        expect(tenure.seat).to be_present
        expect(tenure.seat.position_type).to eq(position_type)
        expect(tenure.seat.state).to eq('filled')
      end

      it 'associates multiple tenures with the same seat when they share position type and date' do
        employee1 = create(:person)
        employee2 = create(:person)
        employee1_teammate = create(:teammate, person: employee1, organization: organization, first_employed_at: 1.year.ago)
        employee2_teammate = create(:teammate, person: employee2, organization: organization, first_employed_at: 1.year.ago)
        
        start_date = 1.year.ago.to_date
        tenure1 = create(:employment_tenure, teammate: employee1_teammate, company: organization, position: position, started_at: start_date, seat: nil)
        tenure2 = create(:employment_tenure, teammate: employee2_teammate, company: organization, position: position, started_at: start_date, seat: nil)
        
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(2) # Two tenures associated with seats (one seat created, two associations)
        
        tenure1.reload
        tenure2.reload
        expect(tenure1.seat_id).to eq(tenure2.seat_id)
        expect(tenure1.seat).to be_present
      end

      it 'uses existing seat if one already exists for the position type and date' do
        employee1 = create(:person)
        employee1_teammate = create(:teammate, person: employee1, organization: organization, first_employed_at: 1.year.ago)
        start_date = 1.year.ago.to_date
        existing_seat = create(:seat, position_type: position_type, seat_needed_by: start_date, state: 'filled')
        tenure = create(:employment_tenure, teammate: employee1_teammate, company: organization, position: position, started_at: start_date, seat: nil)
        
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(1) # One tenure associated with existing seat
        
        tenure.reload
        expect(tenure.seat).to eq(existing_seat)
        expect(Seat.count).to eq(1) # No new seat created
      end
    end

    context 'when all employees already have seats' do
      it 'returns success with zero created count' do
        employee1 = create(:person)
        employee1_teammate = create(:teammate, person: employee1, organization: organization, first_employed_at: 1.year.ago)
        seat = create(:seat, position_type: position_type, seat_needed_by: 1.year.ago.to_date)
        create(:employment_tenure, teammate: employee1_teammate, company: organization, position: position, started_at: 1.year.ago, seat: seat)
        
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(0)
        expect(result[:errors]).to be_empty
      end
    end

    context 'when there are no active employees' do
      it 'returns success with zero created count' do
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(0)
        expect(result[:errors]).to be_empty
      end
    end

    context 'when there are errors' do
      it 'handles validation errors gracefully' do
        # Create a position type that will cause issues
        employee1 = create(:person)
        employee1_teammate = create(:teammate, person: employee1, organization: organization, first_employed_at: 1.year.ago)
        tenure = create(:employment_tenure, teammate: employee1_teammate, company: organization, position: position, started_at: 1.year.ago, seat: nil)
        
        # Stub the seat creation to fail
        allow_any_instance_of(Seat).to receive(:save).and_return(false)
        allow_any_instance_of(Seat).to receive(:errors).and_return(double(full_messages: ['Validation error']))
        
        result = service.call
        
        expect(result[:success]).to be false
        expect(result[:created_count]).to eq(0)
        expect(result[:errors]).not_to be_empty
      end
    end
  end
end

