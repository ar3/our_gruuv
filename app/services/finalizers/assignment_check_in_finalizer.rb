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
      
      return Result.err("No active tenure found for this assignment") unless active_tenure
      
      # Close current tenure with official rating
      active_tenure.update!(
        ended_at: Date.current,
        official_rating: @official_rating
      )
      
      # Create new tenure (same assignment, fresh rating period)
      # Use provided anticipated_energy_percentage, or fallback to old tenure's value if nil
      energy_percentage = @anticipated_energy_percentage.present? ? @anticipated_energy_percentage.to_i : active_tenure.anticipated_energy_percentage
      
      new_tenure = AssignmentTenure.create!(
        teammate: @teammate,
        assignment: @check_in.assignment,
        started_at: Date.current,
        anticipated_energy_percentage: energy_percentage,
        ended_at: nil,
        official_rating: nil
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
          assignment_id: @check_in.assignment.id,
          official_rating: @official_rating,
          rated_at: Date.current.to_s
        }
      )
    end
  end
end
