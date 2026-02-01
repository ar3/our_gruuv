require 'rails_helper'

RSpec.describe Seats::CreateMissingTitleSeatsService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  # Don't create title in let block - create it in tests to avoid it getting a seat
  let(:service) { described_class.new(organization) }

  describe '#call' do
    context 'when titles have no seats' do
      it 'creates seats for titles without seats' do
        title = create(:title, company: organization, position_major_level: position_major_level)
        title2 = create(:title, company: organization, position_major_level: position_major_level, external_title: "Product Manager")
        
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(2) # Both titles
        expect(result[:errors]).to be_empty
        
        expect(Seat.where(title: title).count).to eq(1)
        expect(Seat.where(title: title2).count).to eq(1)
        
        seat = Seat.find_by(title: title)
        expect(seat.seat_needed_by).to eq(Date.current)
        expect(seat.state).to eq('draft')
      end

      it 'creates seat with current date as seat_needed_by' do
        title = create(:title, company: organization, position_major_level: position_major_level)
        result = service.call
        
        seat = Seat.find_by(title: title)
        expect(seat.seat_needed_by).to eq(Date.current)
      end

      it 'creates seat in draft state' do
        title = create(:title, company: organization, position_major_level: position_major_level)
        result = service.call
        
        seat = Seat.find_by(title: title)
        expect(seat.state).to eq('draft')
      end
    end

    context 'when titles already have seats' do
      it 'skips titles that already have seats' do
        title = create(:title, company: organization, position_major_level: position_major_level)
        create(:seat, title: title, seat_needed_by: Date.current)
        title2 = create(:title, company: organization, position_major_level: position_major_level, external_title: "Product Manager")
        
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(1) # Only title2
        expect(result[:errors]).to be_empty
        
        expect(Seat.where(title: title).count).to eq(1)
        expect(Seat.where(title: title2).count).to eq(1)
      end
    end

    context 'when there are no titles' do
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
        title = create(:title, company: organization, position_major_level: position_major_level)
        # Stub the seat creation to fail
        allow_any_instance_of(Seat).to receive(:save).and_return(false)
        allow_any_instance_of(Seat).to receive(:errors).and_return(double(full_messages: ['Validation error']))
        
        result = service.call
        
        expect(result[:success]).to be false
        expect(result[:created_count]).to eq(0)
        expect(result[:errors]).not_to be_empty
      end
    end

    context 'when seat already exists for title and date' do
      it 'skips creating duplicate seat' do
        title = create(:title, company: organization, position_major_level: position_major_level)
        create(:seat, title: title, seat_needed_by: Date.current)
        
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(0)
        expect(Seat.where(title: title).count).to eq(1)
      end
    end
  end
end


