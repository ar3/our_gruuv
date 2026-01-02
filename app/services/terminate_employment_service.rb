class TerminateEmploymentService
  def self.call(teammate:, current_tenure:, termination_date:, created_by:, reason: nil)
    new(teammate: teammate, current_tenure: current_tenure, termination_date: termination_date, created_by: created_by, reason: reason).call
  end

  def initialize(teammate:, current_tenure:, termination_date:, created_by:, reason: nil)
    @teammate = teammate
    @current_tenure = current_tenure
    @termination_date = termination_date
    @created_by = created_by
    @reason = reason
  end

  def call
    ApplicationRecord.transaction do
      # Parse termination_date to ensure we have a Date
      parsed_date = parse_termination_date(@termination_date)
      
      # Convert Date to Time for ended_at (timestamp field)
      ended_at_time = parsed_date.is_a?(Time) ? parsed_date : parsed_date.to_time
      
      # Update employment tenure's ended_at
      @current_tenure.update!(ended_at: ended_at_time)
      
      # Update company teammate's last_terminated_at (use Date, not Time)
      termination_date_value = parsed_date.is_a?(Date) ? parsed_date : parsed_date.to_date
      @teammate.update!(last_terminated_at: termination_date_value)
      
      # Create MAAP snapshot
      create_maap_snapshot(parsed_date)
      
      Result.ok(@current_tenure)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue => e
    Result.err("Failed to terminate employment: #{e.message}")
  end

  private

  attr_reader :teammate, :current_tenure, :termination_date, :created_by, :reason

  def parse_termination_date(date_param)
    # Handle various date formats
    if date_param.is_a?(Date)
      date_param
    elsif date_param.is_a?(Time) || date_param.is_a?(DateTime)
      date_param.to_date
    elsif date_param.is_a?(String)
      date_str = date_param.strip
      if date_str.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        Date.strptime(date_str, '%Y-%m-%d')
      elsif date_str.match?(/\A\d{8}\z/)
        Date.strptime(date_str, '%Y%m%d')
      else
        Date.parse(date_str)
      end
    else
      # Try to convert to string and parse
      Date.parse(date_param.to_s)
    end
  end

  def create_maap_snapshot(effective_date)
    maap_data = MaapSnapshot.build_maap_data_for_employee(
      teammate.person,
      current_tenure.company
    )
    
    # Add employment_tenure data for position_tenure change_type
    maap_data['employment_tenure'] = {
      position_id: current_tenure.position_id,
      manager_teammate_id: current_tenure.manager_teammate_id,
      seat_id: current_tenure.seat_id,
      employment_type: current_tenure.employment_type,
      started_at: current_tenure.started_at.is_a?(Time) ? current_tenure.started_at.iso8601 : current_tenure.started_at.to_time.iso8601,
      ended_at: current_tenure.ended_at ? (current_tenure.ended_at.is_a?(Time) ? current_tenure.ended_at.iso8601 : current_tenure.ended_at.to_time.iso8601) : nil
    }
    
    MaapSnapshot.create!(
      employee: teammate.person,
      created_by: created_by,
      company: current_tenure.company,
      change_type: 'position_tenure',
      reason: reason || 'Employment termination',
      maap_data: maap_data,
      effective_date: effective_date,
      manager_request_info: {}
    )
  end
end

