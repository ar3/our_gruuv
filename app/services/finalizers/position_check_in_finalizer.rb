module Finalizers
  class PositionCheckInFinalizer
    
    def initialize(check_in:, official_rating:, shared_notes:, finalized_by:)
      @check_in = check_in
      @official_rating = official_rating
      @shared_notes = shared_notes
      @finalized_by = finalized_by
      @teammate = check_in.teammate
    end
    
    def finalize
      return Result.err("Check-in not ready") unless @check_in.ready_for_finalization?
      return Result.err("Official rating required") if @official_rating.nil?
      return Result.err("Invalid official rating") unless EmploymentTenure::POSITION_RATINGS.key?(@official_rating)
      
      # Close current tenure with official rating
      current_tenure = @check_in.employment_tenure
      current_tenure.update!(
        ended_at: Date.current,
        official_position_rating: @official_rating
      )
      
      # Open new tenure (same position/manager, fresh rating period)
      new_tenure = EmploymentTenure.create!(
        teammate: @teammate,
        company: current_tenure.company,
        position: current_tenure.position,
        manager: current_tenure.manager,
        seat: current_tenure.seat,
        employment_type: current_tenure.employment_type,
        started_at: Date.current,
        official_position_rating: nil
      )
      
      # Finalize the check-in (snapshot will be linked by orchestrator)
      @check_in.update!(
        official_rating: @official_rating,
        shared_notes: @shared_notes,
        official_check_in_completed_at: Time.current,
        finalized_by: @finalized_by
      )
      
      # Return data for snapshot
      Result.ok(
        check_in: @check_in,
        new_tenure: new_tenure,
        rating_data: {
          position_id: current_tenure.position_id,
          manager_id: current_tenure.manager_id,
          official_rating: @official_rating,
          rated_at: Date.current.to_s
        }
      )
    end
  end
end
