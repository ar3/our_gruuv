module MaapData
  class BulkCheckInFinalizationProcessor
    def initialize(maap_snapshot)
      @maap_snapshot = maap_snapshot
      @employee = maap_snapshot.employee
      @company = maap_snapshot.company
      @form_params = maap_snapshot.form_params
    end

    def process
      Rails.logger.info "BULK_CHECK_IN_PROCESSOR: Processing snapshot #{@maap_snapshot.id}"
      
      maap_data = {
        position: build_position_data,
        assignments: build_assignments_data,
        abilities: build_abilities_data,
        aspirations: build_aspirations_data
      }
      
      Rails.logger.info "BULK_CHECK_IN_PROCESSOR: Built maap_data with #{maap_data[:assignments]&.length || 0} assignments"
      
      maap_data
    end

    private

    def build_position_data
      # For bulk check-in finalization, we typically don't change employment
      # Return current active employment tenure data
      teammate = @employee.teammates.joins(:employment_tenures).where(employment_tenures: { ended_at: nil }).first
      current_employment = teammate&.employment_tenures&.active&.first
      return nil unless current_employment

      {
        position_id: current_employment.position_id,
        manager_id: current_employment.manager_id,
        seat_id: current_employment.seat_id,
        employment_type: current_employment.employment_type,
        official_position_rating: current_employment.official_position_rating
      }
    end

    def build_assignments_data
      # Get all assignments where the person has active tenure, filtered by company
      teammate = @employee.teammates.find_by(organization: @company)
      return [] unless teammate
      
      teammate.assignment_tenures.active.includes(:assignment).joins(:assignment).where(assignments: { company: @company }).map do |tenure|
        {
          assignment_id: tenure.assignment_id,
          anticipated_energy_percentage: tenure.anticipated_energy_percentage,
          official_rating: tenure.official_rating
        }
      end
    end

    def build_abilities_data
      # Get all person milestones for abilities in this company
      teammate = @employee.teammates.find_by(organization: @company)
      return [] unless teammate
      
      milestones = teammate.teammate_milestones.includes(:ability)
               .joins(:ability)
               .where(abilities: { organization: @company })
      
      Rails.logger.info "BULK_CHECK_IN_PROCESSOR: Processing #{milestones.count} abilities"
      
      milestones.map do |milestone|
        {
          ability_id: milestone.ability_id,
          milestone_level: milestone.milestone_level,
          certified_by_id: milestone.certified_by_id,
          attained_at: milestone.attained_at
        }
      end
    end

    def build_aspirations_data
      teammate = @employee.teammates.find_by(organization: @company)
      return [] unless teammate
      
      aspirations = @company.aspirations
      
      aspirations.map do |aspiration|
        # Get the last finalized aspiration_check_in for this teammate and aspiration
        finalized_check_in = AspirationCheckIn.latest_finalized_for(teammate, aspiration)
        
        {
          aspiration_id: aspiration.id,
          official_rating: finalized_check_in&.official_rating
        }
      end
    end
  end
end
