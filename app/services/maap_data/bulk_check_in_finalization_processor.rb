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
        employment_tenure: build_employment_tenure_data,
        assignments: build_assignments_data,
        milestones: build_milestones_data,
        aspirations: build_aspirations_data
      }
      
      Rails.logger.info "BULK_CHECK_IN_PROCESSOR: Built maap_data with #{maap_data[:assignments]&.length || 0} assignments"
      
      maap_data
    end

    private

    def build_employment_tenure_data
      # For bulk check-in finalization, we typically don't change employment
      # Return current active employment tenure data
      current_employment = @employee.employment_tenures.active.first
      return nil unless current_employment

      {
        position_id: current_employment.position_id,
        manager_id: current_employment.manager_id,
        started_at: current_employment.started_at&.strftime('%Y-%m-%d'),
        seat_id: current_employment.seat_id
      }
    end

    def build_assignments_data
      # Get all assignments where the person has ever had a tenure, filtered by company
      assignment_ids = @employee.assignment_tenures.distinct.pluck(:assignment_id)
      assignments = Assignment.where(id: assignment_ids, company: @company).includes(:assignment_tenures)
      
      assignments.map do |assignment|
        active_tenure = @employee.assignment_tenures.where(assignment: assignment).active.first
        most_recent_tenure = @employee.assignment_tenures.where(assignment: assignment).order(:started_at).last
        current_check_in = AssignmentCheckIn.where(person: @employee, assignment: assignment).open.first
        
        assignment_data = {
          id: assignment.id,
          title: assignment.title,
          tenure: build_tenure_data(active_tenure, most_recent_tenure)
        }
        
        # Add check-in data if there's a current check-in OR if there are form changes for this assignment
        current_check_in = AssignmentCheckIn.where(person: @employee, assignment: assignment).open.first
        has_form_changes = @form_params["check_in_data"].present? && @form_params["check_in_data"][assignment.id.to_s].present?
        
        # If no open check-in but there are form changes, look for any check-in for this assignment
        if !current_check_in && has_form_changes
          current_check_in = AssignmentCheckIn.where(person: @employee, assignment: assignment).order(:created_at).last
        end
        
        if current_check_in
          assignment_data[:employee_check_in] = build_employee_check_in_data(current_check_in)
          assignment_data[:manager_check_in] = build_manager_check_in_data(current_check_in, assignment.id)
          assignment_data[:official_check_in] = build_official_check_in_data(current_check_in, assignment.id)
        end
        
        assignment_data
      end.sort_by { |data| -(data[:tenure][:anticipated_energy_percentage] || 0) }
    end

    def build_tenure_data(active_tenure, most_recent_tenure)
      tenure = active_tenure || most_recent_tenure
      return {} unless tenure

      {
        anticipated_energy_percentage: tenure.anticipated_energy_percentage,
        started_at: tenure.started_at&.strftime('%Y-%m-%d'),
        ended_at: tenure.ended_at&.strftime('%Y-%m-%d')
      }
    end

    def build_employee_check_in_data(current_check_in)
      {
        actual_energy_percentage: current_check_in.actual_energy_percentage,
        employee_private_notes: current_check_in.employee_private_notes,
        employee_rating: current_check_in.employee_rating,
        employee_personal_alignment: current_check_in.employee_personal_alignment,
        employee_completed_at: current_check_in.employee_completed_at&.strftime('%Y-%m-%d %H:%M:%S')
      }
    end

    def build_manager_check_in_data(current_check_in, assignment_id)
      # Check if there are any manager check-in form parameters for this assignment
      check_in_id = current_check_in&.id
      
      # Check if we have check_in_data format (hash with assignment IDs as keys)
      if @form_params["check_in_data"].present?
        check_in_data = @form_params["check_in_data"][assignment_id.to_s]
        if check_in_data.present?
          manager_rating = check_in_data["manager_rating"]
          shared_notes = check_in_data["shared_notes"]
          manager_complete = check_in_data["manager_complete"] == true || check_in_data["manager_complete"] == "true"
        else
          manager_rating = nil
          shared_notes = nil
          manager_complete = false
        end
      else
        # Use assignment_id format when check_in_id is nil or when assignment_id format is present
        if check_in_id.nil? || @form_params["check_in_#{assignment_id}_shared_notes"].present?
          manager_rating = @form_params["check_in_#{assignment_id}_manager_rating"]
          shared_notes = @form_params["check_in_#{assignment_id}_shared_notes"]
          # Handle both "true"/"1" and "false"/"0" values explicitly
          manager_complete_param = @form_params["check_in_#{assignment_id}_manager_complete"]
          manager_complete = case manager_complete_param
                            when "true", "1", true, 1
                              true
                            when "false", "0", false, 0
                              false
                            else
                              nil  # No explicit value set
                            end
        else
          manager_rating = @form_params["check_in_#{check_in_id}_manager_rating"] || @form_params["check_in_#{assignment_id}_manager_rating"]
          shared_notes = @form_params["check_in_#{check_in_id}_shared_notes"] || @form_params["check_in_#{assignment_id}_shared_notes"]
          # Handle both "true"/"1" and "false"/"0" values explicitly
          manager_complete_param = @form_params["check_in_#{check_in_id}_manager_complete"] || @form_params["check_in_#{assignment_id}_manager_complete"]
          manager_complete = case manager_complete_param
                            when "true", "1", true, 1
                              true
                            when "false", "0", false, 0
                              false
                            else
                              nil  # No explicit value set
                            end
        end
      end
      
      # Only include if there are form changes or current data
      # Include data if there are explicit form changes OR if manager_complete is explicitly set (even to false)
      has_form_changes = manager_rating.present? || shared_notes.present? || 
                        (@form_params["check_in_data"].present? && 
                         @form_params["check_in_data"][assignment_id.to_s]&.key?("manager_complete"))
      
      # Also include if manager_complete is explicitly set (even to false/0)
      has_explicit_manager_complete = !@form_params["check_in_#{assignment_id}_manager_complete"].nil?
      
      if has_form_changes || has_explicit_manager_complete || current_check_in
        
        {
          manager_private_notes: current_check_in&.manager_private_notes,
          manager_rating: manager_rating.present? ? manager_rating : current_check_in&.manager_rating,
          shared_notes: shared_notes.present? ? shared_notes : current_check_in&.shared_notes,
          manager_completed_at: manager_complete == true ? Time.current : current_check_in&.manager_completed_at&.strftime('%Y-%m-%d %H:%M:%S'),
          manager_completed_by_id: manager_complete == true ? @form_params[:created_by_id] : current_check_in&.manager_completed_by_id
        }
      else
        nil
      end
    end

    def build_official_check_in_data(current_check_in, assignment_id)
      # Check if there are any official check-in form parameters for this assignment
      # Handle both bulk finalization format (check_in_#{check_in_id}_*) and regular format (check_in_#{assignment_id}_*)
      check_in_id = current_check_in&.id
      
      # For bulk finalization, if both employee and manager are completed, we should finalize
      # unless explicitly told not to
      if @form_params["check_in_data"].present?
        check_in_data = @form_params["check_in_data"][assignment_id.to_s]
        if check_in_data.present?
          official_rating = check_in_data["final_rating"]
          shared_notes = check_in_data["shared_notes"]
          # For bulk finalization, finalize if both sides are completed and we have a rating
          official_complete = (check_in_data["close_rating"] == true || check_in_data["close_rating"] == "true") ||
                             (official_rating.present? && current_check_in&.employee_completed_at.present? && current_check_in&.manager_completed_at.present?)
        else
          official_rating = nil
          shared_notes = nil
          official_complete = false
        end
      else
        # Use assignment_id format when check_in_id is nil or when assignment_id format is present
        if check_in_id.nil? || @form_params["check_in_#{assignment_id}_shared_notes"].present?
          official_rating = @form_params["check_in_#{assignment_id}_final_rating"] || @form_params["check_in_#{assignment_id}_official_rating"]
          shared_notes = @form_params["check_in_#{assignment_id}_shared_notes"]
          # For bulk finalization, finalize if both sides are completed and we have a rating
          official_complete = @form_params["check_in_#{assignment_id}_close_rating"] == "true" || 
                             @form_params["check_in_#{assignment_id}_official_complete"] == "1" ||
                             (official_rating.present? && current_check_in&.employee_completed_at.present? && current_check_in&.manager_completed_at.present?)
        else
          official_rating = @form_params["check_in_#{check_in_id}_final_rating"] || @form_params["check_in_#{assignment_id}_official_rating"]
          shared_notes = @form_params["check_in_#{check_in_id}_shared_notes"] || @form_params["check_in_#{assignment_id}_shared_notes"]
          official_complete = @form_params["check_in_#{check_in_id}_close_rating"] == "true" || @form_params["check_in_#{assignment_id}_official_complete"] == "1"
        end
      end
      
      # Only include if there are form changes or current data
      # Include data if:
      # 1. There are form changes (rating, notes, or completion status)
      # 2. There's current data
      # 3. close_rating is explicitly set to false (uncompleting)
      has_form_changes = official_rating.present? || shared_notes.present? || 
                        (@form_params["check_in_data"].present? && 
                         @form_params["check_in_data"][assignment_id.to_s]&.key?("close_rating"))
      
      if has_form_changes || current_check_in
        
        {
          official_rating: official_rating.present? ? official_rating : current_check_in&.official_rating,
          shared_notes: shared_notes.present? ? shared_notes : current_check_in&.shared_notes,
          official_check_in_completed_at: official_complete ? Time.current : (official_complete == false ? nil : current_check_in&.official_check_in_completed_at),
          finalized_by_id: official_complete ? @form_params[:created_by_id] : (official_complete == false ? nil : current_check_in&.finalized_by_id)
        }
      else
        nil
      end
    end

    def build_milestones_data
      # Get all person milestones for abilities in this company
      milestones = @employee.person_milestones.includes(:ability)
               .joins(:ability)
               .where(abilities: { organization: @company })
      
      Rails.logger.info "BULK_CHECK_IN_PROCESSOR: Processing #{milestones.count} milestones"
      
      milestones.map do |milestone|
        {
          id: milestone.id,
          ability_id: milestone.ability_id,
          ability_title: milestone.ability.name,
          milestone_level: milestone.milestone_level,
          certified_by_id: milestone.certified_by_id,
          attained_at: milestone.attained_at&.strftime('%Y-%m-%d')
        }
      end
    end

    def build_aspirations_data
      # Aspirations belong to the organization, not the person
      @company.aspirations.map do |aspiration|
        {
          id: aspiration.id,
          ability_id: aspiration.ability_id,
          ability_title: aspiration.ability.name,
          priority: aspiration.priority,
          target_date: aspiration.target_date&.strftime('%Y-%m-%d')
        }
      end
    end
  end
end
