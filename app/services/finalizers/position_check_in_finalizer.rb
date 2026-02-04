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
      
      # Close ALL active tenures for this teammate/company before creating a new one
      # This ensures there's only one active tenure at a time
      current_tenure = @check_in.employment_tenure
      company = current_tenure.company
      close_time = Time.current
      
      # Close the current tenure (the one associated with the check-in) with the official rating
      current_tenure.update!(
        ended_at: close_time,
        official_position_rating: @official_rating
      )
      
      # Close any other active tenures (shouldn't exist, but handle data integrity issues)
      other_active_tenures = EmploymentTenure
        .where(company_teammate: @teammate, company: company, ended_at: nil)
        .where.not(id: current_tenure.id)
      
      if other_active_tenures.exists?
        other_active_tenures.update_all(ended_at: close_time)
      end
      
      # Open new tenure (same position/manager, fresh rating period)
      new_tenure = EmploymentTenure.create!(
        teammate: @teammate,
        company: company,
        position: current_tenure.position,
        manager_teammate: current_tenure.manager_teammate,
        seat: current_tenure.seat,
        employment_type: current_tenure.employment_type,
        started_at: Time.current,
        official_position_rating: nil
      )
      
      # Finalize the check-in (snapshot will be linked by orchestrator)
      @check_in.update!(
        official_rating: @official_rating,
        shared_notes: @shared_notes,
        official_check_in_completed_at: Time.current,
        finalized_by_teammate: @finalized_by
      )
      
      # Create observable moment if rating improved
      ObservableMoments::CreateCheckInMomentService.call(
        check_in: @check_in,
        finalized_by: @finalized_by
      )
      
      # Return data for snapshot
      Result.ok(
        check_in: @check_in,
        new_tenure: new_tenure,
        rating_data: {
          position_id: current_tenure.position_id,
          manager_teammate_id: current_tenure.manager_teammate_id,
          official_rating: @official_rating,
          rated_at: Time.current.to_s
        }
      )
    end
  end
end
