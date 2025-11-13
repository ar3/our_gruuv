module Seats
  class CreateMissingEmployeeSeatsService
    def initialize(organization)
      @organization = organization
      @created_count = 0
      @errors = []
    end

    def call
      ActiveRecord::Base.transaction do
        active_employment_tenures = EmploymentTenure.active
                                                     .where(company: @organization)
                                                     .where(seat_id: nil)
                                                     .includes(:position, :teammate)
        
        # Preload position_type_ids to ensure correct grouping
        position_ids = active_employment_tenures.map(&:position_id).uniq
        positions_by_id = Position.where(id: position_ids).pluck(:id, :position_type_id).to_h
        
        # Group tenures by position_type_id and date to handle duplicates
        tenures_by_seat_key = active_employment_tenures.group_by do |tenure|
          position_type_id = positions_by_id[tenure.position_id] || tenure.position.position_type_id
          [position_type_id, tenure.started_at.to_date]
        end
        
        tenures_by_seat_key.each do |(position_type_id, seat_needed_by), tenures|
          create_seat_for_tenures(tenures, position_type_id, seat_needed_by)
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

    def create_seat_for_tenures(tenures, position_type_id, seat_needed_by)
      position_type = PositionType.find(position_type_id)
      
      # Check if a seat already exists for this position_type and date
      existing_seat = Seat.find_by(
        position_type_id: position_type_id,
        seat_needed_by: seat_needed_by
      )
      
      seat = existing_seat
      
      unless seat
        # Create a new seat
        seat = Seat.new(
          position_type: position_type,
          seat_needed_by: seat_needed_by,
          state: 'filled' # Already filled since employees are in the tenures
        )
        
        unless seat.save
          @errors << "Failed to create seat for #{position_type.external_title}: #{seat.errors.full_messages.join(', ')}"
          return
        end
      end
      
      # Associate all tenures with the seat and count associations
      tenures.each do |tenure|
        tenure.update!(seat: seat)
        @created_count += 1
      end
    rescue ActiveRecord::RecordNotFound => e
      @errors << "Position type not found: #{e.message}"
    rescue => e
      @errors << "Error creating seat for position type #{position_type_id}: #{e.message}"
    end
  end
end

