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
      ended_at_time = @current_tenure.effective_end_time(ended_at_time)

      # Update employment tenure's ended_at
      @current_tenure.update!(ended_at: ended_at_time)

      # End any assignment tenures the teammate is still actively holding, so a
      # terminated person no longer shows as actively assigned to work.
      close_active_assignment_tenures(ended_at_time) if @teammate.is_a?(CompanyTeammate)

      # Keep teammate-level employment summary fields in sync with tenure state.
      sync_result = EmploymentStateConsistencyService.call(teammate: @teammate)
      raise StandardError, sync_result.error unless sync_result.ok?
      
      # Create MAAP snapshot (only for CompanyTeammates)
      create_maap_snapshot(parsed_date) if @teammate.is_a?(CompanyTeammate)
      
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

  def close_active_assignment_tenures(ended_at_time)
    # AssignmentTenure#ended_at is a date column, so normalize the timestamp.
    end_date = ended_at_time.to_date
    teammate.assignment_tenures.active.find_each do |tenure|
      # ended_at must be >= started_at; a not-yet-started tenure is clamped to
      # its start so termination stays atomic without tripping validation.
      tenure_end = [end_date, tenure.started_at].max
      tenure.update!(ended_at: tenure_end)
    end
  end

  def create_maap_snapshot(effective_date)
    maap_data = MaapSnapshot.build_maap_data_for_teammate(teammate)
    
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
      employee_company_teammate: teammate,
      creator_company_teammate: created_by,
      company: current_tenure.company,
      change_type: 'position_tenure',
      reason: reason || 'Employment termination',
      maap_data: maap_data,
      effective_date: effective_date,
      manager_request_info: {}
    )
  end
end

