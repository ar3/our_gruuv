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
      active_tenure = AssignmentTenure.where(company_teammate: @teammate, assignment: @check_in.assignment)
                                     .where(ended_at: nil)
                                     .first
      
      # Determine the energy percentage value
      energy_percentage = if @anticipated_energy_percentage.present?
                            @anticipated_energy_percentage.to_i
                          elsif active_tenure
                            active_tenure.anticipated_energy_percentage
                          else
                            50
                          end
      
      # If energy is 0% and there's an active tenure, end it without creating a new one
      if energy_percentage == 0 && active_tenure
        active_tenure.update!(
          ended_at: Time.current,
          official_rating: @official_rating
        )
        new_tenure = nil
      elsif active_tenure
        # Existing tenure: close it and create a new one
        # Close current tenure with official rating
        active_tenure.update!(
          ended_at: Time.current,
          official_rating: @official_rating
        )
        
        # Create new tenure (same assignment, fresh rating period)
        new_tenure = AssignmentTenure.create!(
          teammate: @teammate,
          assignment: @check_in.assignment,
          started_at: Time.current,
          anticipated_energy_percentage: energy_percentage,
          ended_at: nil,
          official_rating: nil
        )
      else
        # First check-in: create the first tenure (only if energy is not 0%)
        # If energy is 0%, don't create a tenure
        if energy_percentage == 0
          new_tenure = nil
        else
          new_tenure = AssignmentTenure.create!(
            teammate: @teammate,
            assignment: @check_in.assignment,
            started_at: Time.current,
            anticipated_energy_percentage: energy_percentage,
            ended_at: nil,
            official_rating: nil
          )
        end
      end
      
      # Finalize the check-in (snapshot will be linked by orchestrator)
      @check_in.update!(
        official_rating: @official_rating,
        shared_notes: @shared_notes,
        official_check_in_completed_at: Time.current,
        finalized_by_teammate: @finalized_by
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
