module ObservableMoments
  class CreateSeatChangeMomentService
    def self.call(...) = new(...).call
    
    def initialize(new_employment_tenure:, old_employment_tenure:, created_by:)
      @new_employment_tenure = new_employment_tenure
      @old_employment_tenure = old_employment_tenure
      @created_by = created_by
    end
    
    def call
      # Primary observer is the person who made the change (created_by)
      primary_observer = @created_by.teammates.find_by(organization: @new_employment_tenure.company)
      return Result.err("Could not find creator's teammate in company") unless primary_observer
      
      # Build metadata
      metadata = {
        person_name: @new_employment_tenure.teammate.person.display_name,
        old_position_id: @old_employment_tenure&.position_id,
        old_position_name: @old_employment_tenure&.position&.name,
        new_position_id: @new_employment_tenure.position_id,
        new_position_name: @new_employment_tenure.position&.name,
        old_manager_id: @old_employment_tenure&.manager_teammate_id,
        new_manager_id: @new_employment_tenure.manager_teammate_id
      }
      
      ObservableMoments::BaseObservableMomentService.new(
        momentable: @new_employment_tenure,
        company: @new_employment_tenure.company,
        created_by: @created_by,
        primary_potential_observer: primary_observer,
        moment_type: :seat_change,
        occurred_at: @new_employment_tenure.started_at || Time.current,
        metadata: metadata
      ).call
    end
  end
end

