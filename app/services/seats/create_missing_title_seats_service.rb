module Seats
  class CreateMissingTitleSeatsService
    def initialize(organization)
      @organization = organization
      @created_count = 0
      @errors = []
    end

    def call
      ActiveRecord::Base.transaction do
        titles = @organization.titles.unarchived.includes(:seats)
        
        titles.each do |title|
          next if seat_exists_for_title?(title.id)
          
          create_seat_for_title(title)
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

    def create_seat_for_title(title)
      # Use current date as the default seat_needed_by date
      seat_needed_by = Date.current
      
      # Check if a seat already exists for this title and date
      existing_seat = Seat.left_joins(:seat_titles)
                          .where(seat_needed_by: seat_needed_by)
                          .where('seats.title_id = :title_id OR seat_titles.title_id = :title_id', title_id: title.id)
                          .distinct
                          .first
      
      if existing_seat
        # Seat already exists, nothing to do
        return
      end
      
      # Create a new seat
      seat = Seat.new(
        title: title,
        seat_needed_by: seat_needed_by,
        state: 'draft' # Draft state since it's not yet filled
      )
      
      if seat.save
        @created_count += 1
      else
        @errors << "Failed to create seat for #{title.external_title}: #{seat.errors.full_messages.join(', ')}"
      end
    rescue => e
      @errors << "Error creating seat for title #{title.id}: #{e.message}"
    end

    def seat_exists_for_title?(title_id)
      Seat.left_joins(:seat_titles)
          .where('seats.title_id = :title_id OR seat_titles.title_id = :title_id', title_id: title_id)
          .exists?
    end
  end
end
