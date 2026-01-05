module Finalizers
  class AspirationCheckInFinalizer
    
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
      
      # Finalize the check-in
      @check_in.update!(
        official_rating: @official_rating,
        shared_notes: @shared_notes,
        official_check_in_completed_at: Time.current,
        finalized_by: @finalized_by
      )
      
      # Create observable moment if rating improved
      ObservableMoments::CreateCheckInMomentService.call(
        check_in: @check_in,
        finalized_by: @finalized_by
      )
      
      # Return data for snapshot
      Result.ok(
        check_in: @check_in,
        rating_data: {
          aspiration_id: @check_in.aspiration.id,
          official_rating: @official_rating,
          rated_at: Date.current.to_s
        }
      )
    end
  end
end
