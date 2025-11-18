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
      active_employment = teammate&.employment_tenures&.active&.first
      return nil unless active_employment

      # Find most recent closed employment tenure
      previous_closed_tenure = teammate.employment_tenures
        .for_company(@company)
        .inactive
        .order(ended_at: :desc)
        .first
      
      rated_position = if previous_closed_tenure
        {
          seat_id: previous_closed_tenure.seat_id,
          manager_id: previous_closed_tenure.manager_id,
          position_id: previous_closed_tenure.position_id,
          employment_type: previous_closed_tenure.employment_type,
          official_position_rating: previous_closed_tenure.official_position_rating,
          started_at: previous_closed_tenure.started_at.to_time.iso8601,
          ended_at: previous_closed_tenure.ended_at.to_time.iso8601
        }
      else
        {}
      end

      {
        position_id: active_employment.position_id,
        manager_id: active_employment.manager_id,
        seat_id: active_employment.seat_id,
        employment_type: active_employment.employment_type,
        rated_position: rated_position
      }
    end

    def build_assignments_data
      # Get all assignments where the person has active tenure, filtered by company
      teammate = @employee.teammates.find_by(organization: @company)
      return [] unless teammate
      
      teammate.assignment_tenures.active.includes(:assignment).joins(:assignment).where(assignments: { company: @company }).map do |active_tenure|
        # Find most recent closed assignment tenure for this assignment
        previous_closed_tenure = teammate.assignment_tenures
          .where(assignment: active_tenure.assignment)
          .where.not(ended_at: nil)
          .order(ended_at: :desc)
          .first
        
        rated_assignment = if previous_closed_tenure
          {
            assignment_id: previous_closed_tenure.assignment_id,
            anticipated_energy_percentage: previous_closed_tenure.anticipated_energy_percentage,
            official_rating: previous_closed_tenure.official_rating,
            started_at: previous_closed_tenure.started_at.to_time.iso8601,
            ended_at: previous_closed_tenure.ended_at.to_time.iso8601
          }
        else
          {}
        end
        
        assignment_data = {
          assignment_id: active_tenure.assignment_id,
          anticipated_energy_percentage: active_tenure.anticipated_energy_percentage,
          rated_assignment: rated_assignment
        }
        
        # Process check-in data from form_params if present
        check_in_data = extract_check_in_data_for_assignment(active_tenure.assignment_id)
        if check_in_data
          # Build official_check_in if there's any official check-in related data
          if check_in_data['close_rating'] || check_in_data['final_rating'] || check_in_data['official_rating'] || check_in_data['shared_notes']
            assignment_data['official_check_in'] = build_official_check_in_data(check_in_data)
          end
          
          # Build manager_check_in if there's any manager check-in related data
          if check_in_data['manager_complete'] || check_in_data['manager_rating'] || check_in_data['shared_notes']
            assignment_data['manager_check_in'] = build_manager_check_in_data(check_in_data)
          end
        end
        
        assignment_data
      end
    end
    
    def extract_check_in_data_for_assignment(assignment_id)
      return nil unless @form_params.present?
      
      # Try check_in_data hash format first
      if @form_params['check_in_data'] && @form_params['check_in_data'][assignment_id.to_s]
        return @form_params['check_in_data'][assignment_id.to_s]
      end
      
      # Try individual key format
      check_in_data = {}
      prefix = "check_in_#{assignment_id}_"
      
      @form_params.each do |key, value|
        next unless key.to_s.start_with?(prefix)
        field_name = key.to_s.sub(prefix, '')
        check_in_data[field_name] = value
      end
      
      return nil if check_in_data.empty?
      check_in_data
    end
    
    def build_official_check_in_data(check_in_data)
      # Determine if check-in should be marked as completed
      close_rating = check_in_data['close_rating']
      should_complete = close_rating == true || close_rating == 'true' || close_rating == '1'
      
      official_check_in = {
        official_rating: check_in_data['final_rating'] || check_in_data['official_rating'],
        shared_notes: check_in_data['shared_notes']
      }
      
      if should_complete
        official_check_in['official_check_in_completed_at'] = Time.current.iso8601
        official_check_in['finalized_by_id'] = @maap_snapshot.created_by_id
      else
        official_check_in['official_check_in_completed_at'] = nil
        official_check_in['finalized_by_id'] = nil
      end
      
      official_check_in
    end
    
    def build_manager_check_in_data(check_in_data)
      # Determine if manager check-in should be marked as completed
      manager_complete = check_in_data['manager_complete']
      should_complete = manager_complete == true || manager_complete == 'true' || manager_complete == '1'
      
      manager_check_in = {
        manager_rating: check_in_data['manager_rating'],
        shared_notes: check_in_data['shared_notes']
      }
      
      if should_complete
        manager_check_in['manager_completed_at'] = Time.current.iso8601
        manager_check_in['manager_completed_by_id'] = @maap_snapshot.created_by_id
      else
        manager_check_in['manager_completed_at'] = nil
        manager_check_in['manager_completed_by_id'] = nil
      end
      
      manager_check_in
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
