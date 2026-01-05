module Finalizers
  class AssignmentCheckInFinalizer
    
    def initialize(check_in:, official_rating:, shared_notes:, anticipated_energy_percentage:, finalized_by:)
      @check_in = check_in
      @official_rating = official_rating
      @shared_notes = shared_notes
      @anticipated_energy_percentage = anticipated_energy_percentage
      @finalized_by = finalized_by
      @teammate = check_in.teammate
    end
    
    def finalize
      return Result.err("Check-in not ready") unless @check_in.ready_for_finalization?
      return Result.err("Official rating required") if @official_rating.nil?
      
      # Find active tenure for this assignment
      active_tenure = AssignmentTenure.where(teammate: @teammate, assignment: @check_in.assignment)
                                     .where(ended_at: nil)
                                     .first
      
      if active_tenure
        # Existing tenure: close it and create a new one
        # Close current tenure with official rating
        active_tenure.update!(
          ended_at: Time.current,
          official_rating: @official_rating
        )
        
        # Create new tenure (same assignment, fresh rating period)
        # Use provided anticipated_energy_percentage, or fallback to old tenure's value if nil
        energy_percentage = @anticipated_energy_percentage.present? ? @anticipated_energy_percentage.to_i : active_tenure.anticipated_energy_percentage
        
        new_tenure = AssignmentTenure.create!(
          teammate: @teammate,
          assignment: @check_in.assignment,
          started_at: Time.current,
          anticipated_energy_percentage: energy_percentage,
          ended_at: nil,
          official_rating: nil
        )
      else
        # First check-in: create the first tenure
        # Use provided anticipated_energy_percentage, or default to 50 if not provided
        energy_percentage = @anticipated_energy_percentage.present? ? @anticipated_energy_percentage.to_i : 50
        
        new_tenure = AssignmentTenure.create!(
          teammate: @teammate,
          assignment: @check_in.assignment,
          started_at: Time.current,
          anticipated_energy_percentage: energy_percentage,
          ended_at: nil,
          official_rating: nil
        )
      end
      
      # Finalize the check-in (snapshot will be linked by orchestrator)
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
        new_tenure: new_tenure,
        rating_data: {
          assignment_id: @check_in.assignment.id,
          official_rating: @official_rating,
          rated_at: Time.current.to_s
        }
      )
    end
  end
end
