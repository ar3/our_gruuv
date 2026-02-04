module ObservableMoments
  class CreateNewHireMomentService
    def self.call(...) = new(...).call
    
    def initialize(employment_tenure:, created_by:)
      @employment_tenure = employment_tenure
      @created_by = created_by
    end
    
    def call
      # Determine primary_potential_observer: manager or creator
      primary_observer = determine_primary_observer
      return Result.err("Could not determine primary potential observer") unless primary_observer
      
      # Build metadata
      metadata = {
        person_name: @employment_tenure.teammate.person.display_name,
        position_id: @employment_tenure.position_id,
        position_name: @employment_tenure.position&.display_name
      }
      
      ObservableMoments::BaseObservableMomentService.new(
        momentable: @employment_tenure,
        company: @employment_tenure.company,
        created_by: @created_by,
        primary_potential_observer: primary_observer,
        moment_type: :new_hire,
        occurred_at: @employment_tenure.started_at || Time.current,
        metadata: metadata
      ).call
    end
    
    private
    
    def determine_primary_observer
      # Try manager first
      if @employment_tenure.manager_teammate.present?
        @employment_tenure.manager_teammate
      else
        # Fall back to creator's teammate in the same company
        # If created_by is already a CompanyTeammate in the same organization, use it directly
        # Otherwise, find the person's teammate in the company
        if @created_by.is_a?(CompanyTeammate) && @created_by.organization_id == @employment_tenure.company_id
          @created_by
        elsif @created_by.is_a?(CompanyTeammate)
          @created_by.person.teammates.find_by(organization: @employment_tenure.company)
        else
          @created_by.teammates.find_by(organization: @employment_tenure.company)
        end
      end
    end
  end
end

