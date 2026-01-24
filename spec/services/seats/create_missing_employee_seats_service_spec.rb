require 'rails_helper'

RSpec.describe Seats::CreateMissingEmployeeSeatsService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:title) { create(:title, organization: organization, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:service) { described_class.new(organization) }

  describe '#call' do
    context 'when employees have no seats' do
      it 'creates seats for employees without seats' do
        employee1 = create(:person)
        employee1_teammate = create(:teammate, person: employee1, organization: organization, first_employed_at: 1.year.ago)
        # Create tenure with position - ensure title is set correctly
        tenure = create(:employment_tenure, teammate: employee1_teammate, company: organization, position: position, started_at: 1.year.ago, seat: nil)
        # Reload to ensure associations are fresh
        tenure.position.reload
        
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(1)
        expect(result[:errors]).to be_empty
        
        tenure.reload
        expect(tenure.seat).to be_present
        # Verify the seat's title matches the tenure's position's title
        expect(tenure.seat.title_id).to eq(tenure.position.title_id)
        expect(tenure.seat.state).to eq('filled')
      end

      it 'associates multiple tenures with the same seat when they share position type and date' do
        employee1 = create(:person)
        employee2 = create(:person)
        employee1_teammate = create(:teammate, person: employee1, organization: organization, first_employed_at: 1.year.ago)
        employee2_teammate = create(:teammate, person: employee2, organization: organization, first_employed_at: 1.year.ago)
        
        start_date = 1.year.ago.to_date
        # Ensure position is persisted
        position.save! unless position.persisted?
        
        # Build tenures without the factory's after_build hook creating new positions
        # The factory has an after_build that creates a position, so we need to build then assign
        tenure1 = build(:employment_tenure, teammate: employee1_teammate, company: organization, started_at: start_date, seat: nil)
        tenure1.position = position
        tenure1.save!
        
        tenure2 = build(:employment_tenure, teammate: employee2_teammate, company: organization, started_at: start_date, seat: nil)
        tenure2.position = position
        tenure2.save!
        
        # Verify both tenures have the same position and title_id before service call
        expect(tenure1.position_id).to eq(tenure2.position_id)
        # Reload positions to ensure they're fresh
        tenure1.position.reload
        tenure2.position.reload
        expect(tenure1.position.title_id).to eq(tenure2.position.title_id)
        # Verify they have the same started_at date
        expect(tenure1.started_at.to_date).to eq(tenure2.started_at.to_date)
        
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
        tenure = create(:employment_tenure, teammate: employee1_teammate, company: organization, position: position, started_at: start_date, seat: nil)
        # Reload to ensure associations are fresh, then create seat with matching title
        tenure.position.reload
        existing_seat = create(:seat, title_id: tenure.position.title_id, seat_needed_by: start_date, state: 'filled')
        
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(1) # One tenure associated with existing seat
        
        tenure.reload
        expect(tenure.seat_id).to eq(existing_seat.id)
        expect(Seat.count).to eq(1) # No new seat created
      end
    end

    context 'when all employees already have seats' do
      it 'returns success with zero created count' do
        employee1 = create(:person)
        employee1_teammate = create(:teammate, person: employee1, organization: organization, first_employed_at: 1.year.ago)
        tenure = create(:employment_tenure, teammate: employee1_teammate, company: organization, position: position, started_at: 1.year.ago, seat: nil)
        # Reload to ensure associations are fresh, then create seat with matching title
        tenure.position.reload
        seat = create(:seat, title_id: tenure.position.title_id, seat_needed_by: 1.year.ago.to_date)
        tenure.update!(seat: seat)
        
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

