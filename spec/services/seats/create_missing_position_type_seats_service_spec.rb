require 'rails_helper'

RSpec.describe Seats::CreateMissingPositionTypeSeatsService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  # Don't create position_type in let block - create it in tests to avoid it getting a seat
  let(:service) { described_class.new(organization) }

  describe '#call' do
    context 'when position types have no seats' do
      it 'creates seats for position types without seats' do
        position_type = create(:position_type, organization: organization, position_major_level: position_major_level)
        position_type2 = create(:position_type, organization: organization, position_major_level: position_major_level, external_title: "Product Manager")
        
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(2) # Both position types
        expect(result[:errors]).to be_empty
        
        expect(Seat.where(position_type: position_type).count).to eq(1)
        expect(Seat.where(position_type: position_type2).count).to eq(1)
        
        seat = Seat.find_by(position_type: position_type)
        expect(seat.seat_needed_by).to eq(Date.current)
        expect(seat.state).to eq('draft')
      end

      it 'creates seat with current date as seat_needed_by' do
        position_type = create(:position_type, organization: organization, position_major_level: position_major_level)
        result = service.call
        
        seat = Seat.find_by(position_type: position_type)
        expect(seat.seat_needed_by).to eq(Date.current)
      end

      it 'creates seat in draft state' do
        position_type = create(:position_type, organization: organization, position_major_level: position_major_level)
        result = service.call
        
        seat = Seat.find_by(position_type: position_type)
        expect(seat.state).to eq('draft')
      end
    end

    context 'when position types already have seats' do
      it 'skips position types that already have seats' do
        position_type = create(:position_type, organization: organization, position_major_level: position_major_level)
        create(:seat, position_type: position_type, seat_needed_by: Date.current)
        position_type2 = create(:position_type, organization: organization, position_major_level: position_major_level, external_title: "Product Manager")
        
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(1) # Only position_type2
        expect(result[:errors]).to be_empty
        
        expect(Seat.where(position_type: position_type).count).to eq(1)
        expect(Seat.where(position_type: position_type2).count).to eq(1)
      end
    end

    context 'when there are no position types' do
      it 'returns success with zero created count' do
        organization2 = create(:organization, :company)
        service2 = described_class.new(organization2)
        
        result = service2.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(0)
        expect(result[:errors]).to be_empty
      end
    end

    context 'when there are errors' do
      it 'handles validation errors gracefully' do
        position_type = create(:position_type, organization: organization, position_major_level: position_major_level)
        # Stub the seat creation to fail
        allow_any_instance_of(Seat).to receive(:save).and_return(false)
        allow_any_instance_of(Seat).to receive(:errors).and_return(double(full_messages: ['Validation error']))
        
        result = service.call
        
        expect(result[:success]).to be false
        expect(result[:created_count]).to eq(0)
        expect(result[:errors]).not_to be_empty
      end
    end

    context 'when seat already exists for position type and date' do
      it 'skips creating duplicate seat' do
        position_type = create(:position_type, organization: organization, position_major_level: position_major_level)
        create(:seat, position_type: position_type, seat_needed_by: Date.current)
        
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(0)
        expect(Seat.where(position_type: position_type).count).to eq(1)
      end
    end
  end
end


