class Organizations::CheckInsHealthController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized
  
  def index
    # Authorization: require manage_employment permission
    authorize @organization, :check_ins_health?
    
    # Get all active employees (teammates with active employment)
    active_teammates = Teammate.for_organization_hierarchy(@organization)
      .where.not(first_employed_at: nil)
      .where(last_terminated_at: nil)
      .includes(:person, :employment_tenures, :organization)
      .joins(:person)
      .order('people.last_name ASC, people.first_name ASC')
    
    # Calculate health status for each teammate
    all_employee_health_data = active_teammates.map do |teammate|
      health_data = CheckInHealthService.call(teammate, @organization)
      {
        teammate: teammate,
        person: teammate.person,
        health: health_data
      }
    end
    
    # Calculate spotlight statistics from all data (before pagination)
    @spotlight_stats = calculate_spotlight_stats(all_employee_health_data)
    
    # Paginate
    @pagy = Pagy.new(count: all_employee_health_data.count, page: params[:page] || 1, items: 25)
    @employee_health_data = all_employee_health_data[@pagy.offset, @pagy.items]
  end
  
  private
  
  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access this page.'
    end
  end
  
  def calculate_spotlight_stats(employee_health_data)
    total_employees = employee_health_data.count
    
    # Count employees with all concerns healthy (all success or no requirements)
    all_healthy = employee_health_data.count do |data|
      health = data[:health]
      health[:position][:status] == :success &&
      (health[:assignments][:status] == :success || health[:assignments][:total_count] == 0) &&
      (health[:aspirations][:status] == :success || health[:aspirations][:total_count] == 0) &&
      (health[:milestones][:status] == :success || health[:milestones][:required_count] == 0)
    end
    
    # Count employees needing attention (any alarm or warning)
    needing_attention = employee_health_data.count do |data|
      health = data[:health]
      [:alarm, :warning].include?(health[:position][:status]) ||
      [:alarm, :warning].include?(health[:assignments][:status]) ||
      [:alarm, :warning].include?(health[:aspirations][:status]) ||
      [:alarm, :warning].include?(health[:milestones][:status])
    end
    
    # Calculate average check-in completion rate
    total_concerns = 0
    completed_concerns = 0
    
    employee_health_data.each do |data|
      health = data[:health]
      
      # Position
      total_concerns += 1
      completed_concerns += 1 if health[:position][:status] == :success
      
      # Assignments
      if health[:assignments][:total_count] > 0
        total_concerns += 1
        completed_concerns += 1 if health[:assignments][:status] == :success
      end
      
      # Aspirations
      if health[:aspirations][:total_count] > 0
        total_concerns += 1
        completed_concerns += 1 if health[:aspirations][:status] == :success
      end
      
      # Milestones
      if health[:milestones][:required_count] > 0
        total_concerns += 1
        completed_concerns += 1 if health[:milestones][:status] == :success
      end
    end
    
    completion_rate = total_concerns > 0 ? (completed_concerns.to_f / total_concerns * 100).round(1) : 0
    
    {
      total_employees: total_employees,
      all_healthy: all_healthy,
      needing_attention: needing_attention,
      completion_rate: completion_rate
    }
  end
end

