module Seats
  class CreateMissingPositionTypeSeatsService
    def initialize(organization)
      @organization = organization
      @created_count = 0
      @errors = []
    end

    def call
      ActiveRecord::Base.transaction do
        position_types = @organization.position_types.includes(:seats)
        
        position_types.each do |position_type|
          next if position_type.seats.exists?
          
          create_seat_for_position_type(position_type)
        end

        {
          success: @errors.empty?,
          created_count: @created_count,
          errors: @errors
        }
      end
    rescue => e
      {
        success: false,
        created_count: @created_count,
        errors: @errors + ["Unexpected error: #{e.message}"]
      }
    end

    private

    def create_seat_for_position_type(position_type)
      # Use current date as the default seat_needed_by date
      seat_needed_by = Date.current
      
      # Check if a seat already exists for this position_type and date
      existing_seat = Seat.find_by(
        position_type: position_type,
        seat_needed_by: seat_needed_by
      )
      
      if existing_seat
        # Seat already exists, nothing to do
        return
      end
      
      # Create a new seat
      seat = Seat.new(
        position_type: position_type,
        seat_needed_by: seat_needed_by,
        state: 'draft' # Draft state since it's not yet filled
      )
      
      if seat.save
        @created_count += 1
      else
        @errors << "Failed to create seat for #{position_type.external_title}: #{seat.errors.full_messages.join(', ')}"
      end
    rescue => e
      @errors << "Error creating seat for position type #{position_type.id}: #{e.message}"
    end
  end
end


