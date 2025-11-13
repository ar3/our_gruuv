class UpdateEmploymentTenureService
  def self.call(teammate:, current_tenure:, params:, created_by:)
    new(teammate: teammate, current_tenure: current_tenure, params: params, created_by: created_by).call
  end

  def initialize(teammate:, current_tenure:, params:, created_by:)
    @teammate = teammate
    @current_tenure = current_tenure
    @params = params
    @created_by = created_by
  end

  def call
    ApplicationRecord.transaction do
      # Detect what changed
      manager_changed = manager_id_changed?
      position_changed = position_id_changed?
      employment_type_changed = employment_type_changed?
      seat_changed = seat_id_changed?
      termination_date_provided = @params[:termination_date].present?
      
      # Determine if we need to create a new tenure
      major_changes = manager_changed || position_changed || employment_type_changed
      needs_new_tenure = major_changes && !termination_date_provided
      needs_snapshot = major_changes || termination_date_provided
      
      if termination_date_provided
        # Update current tenure's ended_at
        @current_tenure.update!(ended_at: @params[:termination_date])
        updated_tenure = @current_tenure
      elsif needs_new_tenure
        # End current tenure and create new one
        @current_tenure.update!(ended_at: Date.current)
        updated_tenure = create_new_tenure
      elsif seat_changed
        # Just update the seat
        @current_tenure.update!(seat_id: @params[:seat_id])
        updated_tenure = @current_tenure
      else
        # No changes
        updated_tenure = @current_tenure
      end
      
      # Create maap_snapshot if needed
      if needs_snapshot
        create_maap_snapshot(updated_tenure)
      end
      
      Result.ok(updated_tenure)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue => e
    Result.err("Failed to update employment tenure: #{e.message}")
  end

  private

  attr_reader :teammate, :current_tenure, :params, :created_by

  def manager_id_changed?
    return false if params[:manager_id].nil?
    # Handle empty string as "clear manager" (nil)
    new_manager_id = params[:manager_id].to_s == '' ? nil : params[:manager_id]
    current_tenure.manager_id.to_s != new_manager_id.to_s
  end

  def position_id_changed?
    return false if params[:position_id].nil?
    current_tenure.position_id.to_s != params[:position_id].to_s
  end

  def employment_type_changed?
    return false if params[:employment_type].nil? || params[:employment_type].blank?
    current_tenure.employment_type.to_s != params[:employment_type].to_s
  end

  def seat_id_changed?
    return false if params[:seat_id].nil?
    # Handle empty string as "clear seat" (nil)
    new_seat_id = params[:seat_id].to_s == '' ? nil : params[:seat_id]
    current_tenure.seat_id.to_s != new_seat_id.to_s
  end

  def create_new_tenure
    # Copy all attributes from current tenure, then update with new values
    # Handle empty strings as nil (to clear fields)
    manager_id_value = if params[:manager_id].present?
                         params[:manager_id].to_s == '' ? nil : params[:manager_id]
                       else
                         current_tenure.manager_id
                       end
    
    seat_id_value = if params[:seat_id].present?
                      params[:seat_id].to_s == '' ? nil : params[:seat_id]
                    else
                      current_tenure.seat_id
                    end
    
    new_tenure = EmploymentTenure.new(
      teammate: current_tenure.teammate,
      company: current_tenure.company,
      position_id: params[:position_id] || current_tenure.position_id,
      manager_id: manager_id_value,
      employment_type: params[:employment_type].presence || current_tenure.employment_type,
      seat_id: seat_id_value,
      started_at: Date.current,
      ended_at: nil,
      official_position_rating: current_tenure.official_position_rating
    )
    
    new_tenure.save!
    new_tenure
  end

  def create_maap_snapshot(tenure)
    effective_date = params[:termination_date] || Date.current
    
    maap_data = {
      employment_tenure: {
        position_id: tenure.position_id,
        manager_id: tenure.manager_id,
        started_at: tenure.started_at,
        seat_id: tenure.seat_id
      },
      assignments: [],
      milestones: [],
      aspirations: []
    }
    
    MaapSnapshot.create!(
      employee: teammate.person,
      created_by: created_by,
      company: current_tenure.company,
      change_type: 'position_tenure',
      reason: params[:reason] || 'Position tenure update',
      maap_data: maap_data,
      effective_date: effective_date,
      manager_request_info: {}
    )
  end
end

