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
      manager_changed = manager_teammate_id_changed?
      position_changed = position_id_changed?
      employment_type_changed = employment_type_changed?
      seat_changed = seat_id_changed?
      termination_date_provided = @params[:termination_date].present?
      
      # Determine if we need to create a new tenure
      major_changes = manager_changed || position_changed || employment_type_changed
      needs_new_tenure = major_changes && !termination_date_provided
      needs_snapshot = major_changes || termination_date_provided
      
      if termination_date_provided
        # Parse termination_date string to Date
        term_date_param = @params[:termination_date]
        
        # Debug: Log what we're receiving
        Rails.logger.debug "DEBUG UpdateEmploymentTenureService: termination_date param class: #{term_date_param.class}, value: #{term_date_param.inspect}"
        
        # Ensure we have a string - if it's already a Date, use it directly
        parsed_date = if term_date_param.is_a?(Date)
          term_date_param
        elsif term_date_param.is_a?(Time) || term_date_param.is_a?(DateTime)
          term_date_param.to_date
        elsif term_date_param.is_a?(String)
          # Handle YYYY-MM-DD format (HTML5 date input format)
          date_str = term_date_param.strip
          Rails.logger.debug "DEBUG UpdateEmploymentTenureService: date_str: #{date_str.inspect}"
          # Validate format first - must be exactly YYYY-MM-DD
          if date_str.match?(/\A\d{4}-\d{2}-\d{2}\z/)
            Date.strptime(date_str, '%Y-%m-%d')
          else
            # Fallback to Date.parse for other formats
            Date.parse(date_str)
          end
        elsif term_date_param.is_a?(Integer) || term_date_param.is_a?(Float)
          # If we get a number, it's likely corrupted - try to reconstruct from it
          num_str = term_date_param.to_s
          Rails.logger.debug "DEBUG UpdateEmploymentTenureService: Received numeric date param: #{term_date_param.inspect}, num_str: #{num_str.inspect}"
          if num_str.length == 8 && num_str.match?(/\A\d{8}\z/)
            # Might be YYYYMMDD format without dashes (e.g., 20251128)
            Date.strptime(num_str, '%Y%m%d')
          else
            # Can't parse as date - raise error
            raise ArgumentError, "Invalid date parameter (numeric): #{term_date_param}. Expected string format YYYY-MM-DD."
          end
        else
          # Convert to string and parse
          date_str = term_date_param.to_s.strip
          Rails.logger.debug "DEBUG UpdateEmploymentTenureService: Converting to string: #{date_str.inspect}"
          if date_str.match?(/\A\d{4}-\d{2}-\d{2}\z/)
            Date.strptime(date_str, '%Y-%m-%d')
          elsif date_str.match?(/\A\d{8}\z/)
            # Handle YYYYMMDD format without dashes
            Date.strptime(date_str, '%Y%m%d')
          else
            Date.parse(date_str)
          end
        end
        
        Rails.logger.debug "DEBUG UpdateEmploymentTenureService: parsed_date: #{parsed_date.inspect}"
        
        # Update current tenure's ended_at (convert Date to Time for timestamp)
        ended_at_time = parsed_date.is_a?(Time) ? parsed_date : parsed_date.to_time
        @current_tenure.update!(ended_at: ended_at_time)
        updated_tenure = @current_tenure
      elsif needs_new_tenure
        # End current tenure and create new one
        @current_tenure.update!(ended_at: Time.current)
        updated_tenure = create_new_tenure
      elsif seat_changed
        # Just update the seat
        # Handle empty string as "clear seat" (nil)
        seat_id_value = @params[:seat_id].to_s == '' ? nil : @params[:seat_id]
        @current_tenure.update!(seat_id: seat_id_value)
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

  def manager_teammate_id_changed?
    return false if params[:manager_teammate_id].nil?
    # Handle empty string as "clear manager" (nil)
    new_manager_teammate_id = params[:manager_teammate_id].to_s == '' ? nil : params[:manager_teammate_id]
    current_tenure.manager_teammate_id.to_s != new_manager_teammate_id.to_s
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
    # Handle empty string as "clear seat" (nil)
    new_seat_id = if params[:seat_id].nil?
                    nil
                  elsif params[:seat_id].to_s == ''
                    nil
                  else
                    params[:seat_id]
                  end
    current_tenure.seat_id.to_s != new_seat_id.to_s
  end

  def create_new_tenure
    # Copy all attributes from current tenure, then update with new values
    # Handle empty strings as nil (to clear fields)
    manager_teammate_id_value = if params[:manager_teammate_id].present?
                                   params[:manager_teammate_id].to_s == '' ? nil : params[:manager_teammate_id]
                                 else
                                   current_tenure.manager_teammate_id
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
      manager_teammate_id: manager_teammate_id_value,
      employment_type: params[:employment_type].presence || current_tenure.employment_type,
      seat_id: seat_id_value,
      started_at: Time.current,
      ended_at: nil,
      official_position_rating: current_tenure.official_position_rating
    )
    
    new_tenure.save!
    new_tenure
  end

  def create_maap_snapshot(tenure)
    effective_date = if params[:termination_date].present?
      if params[:termination_date].is_a?(String)
        Date.strptime(params[:termination_date], '%Y-%m-%d')
      else
        params[:termination_date]
      end
    else
      Date.current
    end
    
    maap_data = MaapSnapshot.build_maap_data_for_employee(
      teammate.person,
      current_tenure.company
    )
    
    # Add employment_tenure data for position_tenure change_type
    maap_data['employment_tenure'] = {
      position_id: tenure.position_id,
      manager_teammate_id: tenure.manager_teammate_id,
      seat_id: tenure.seat_id,
      employment_type: tenure.employment_type,
      started_at: tenure.started_at.is_a?(Time) ? tenure.started_at.iso8601 : tenure.started_at.to_time.iso8601,
      ended_at: tenure.ended_at ? (tenure.ended_at.is_a?(Time) ? tenure.ended_at.iso8601 : tenure.ended_at.to_time.iso8601) : nil
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

