class TeammateStatus
  attr_reader :teammate

  def initialize(teammate)
    @teammate = teammate
  end

  def status
    case
    when terminated?
      :terminated
    when assigned_employee?
      :assigned_employee
    when unassigned_employee?
      :unassigned_employee
    when huddler?
      :huddler
    when follower?
      :follower
    else
      :unknown
    end
  end

  def status_name
    status.to_s.humanize
  end

  def progress_percentage
    case status
    when :follower then 25
    when :huddler then 50
    when :unassigned_employee then 75
    when :assigned_employee then 100
    when :terminated then 0
    else 0
    end
  end

  def badge_class
    case status
    when :follower then "bg-secondary"
    when :huddler then "bg-info"
    when :unassigned_employee then "bg-warning"
    when :assigned_employee then "bg-success"
    when :terminated then "bg-danger"
    else "bg-light text-dark"
    end
  end

  def icon_class
    case status
    when :follower then "bi-person-follow"
    when :huddler then "bi-people"
    when :unassigned_employee then "bi-person-exclamation"
    when :assigned_employee then "bi-person-check"
    when :terminated then "bi-person-x"
    else "bi-question-circle"
    end
  end

  def debug_info
    {
      first_employed_at: teammate.first_employed_at&.strftime('%Y-%m-%d') || 'nil',
      last_terminated_at: teammate.last_terminated_at&.strftime('%Y-%m-%d') || 'nil',
      has_huddle_participation: has_huddle_participation?,
      has_active_employment_tenure: has_active_employment_tenure?,
      organization: teammate.organization.name,
      status_checks: {
        terminated: terminated?,
        assigned_employee: assigned_employee?,
        unassigned_employee: unassigned_employee?,
        huddler: huddler?,
        follower: follower?
      }
    }
  end

  def tooltip_content
    info = debug_info
    "Status Details:\n" +
    "• first_employed_at: #{info[:first_employed_at]}\n" +
    "• last_terminated_at: #{info[:last_terminated_at]}\n" +
    "• has_huddle_participation: #{info[:has_huddle_participation]}\n" +
    "• has_active_employment_tenure: #{info[:has_active_employment_tenure]}\n" +
    "• Organization: #{info[:organization]}\n\n" +
    "Status Checks:\n" +
    info[:status_checks].map { |check, result| "• #{check}: #{result}" }.join("\n")
  end

  private

  def terminated?
    teammate.last_terminated_at.present?
  end

  def assigned_employee?
    teammate.first_employed_at.present? && 
    teammate.last_terminated_at.nil? && 
    has_active_employment_tenure?
  end

  def unassigned_employee?
    teammate.first_employed_at.present? && 
    teammate.last_terminated_at.nil? && 
    !has_active_employment_tenure?
  end

  def huddler?
    teammate.first_employed_at.nil? && 
    teammate.last_terminated_at.nil? && 
    has_huddle_participation?
  end

  def follower?
    teammate.first_employed_at.nil? && 
    teammate.last_terminated_at.nil? && 
    !has_huddle_participation?
  end

  def has_huddle_participation?
    organizations_to_check = teammate.organization.company? ? 
      teammate.organization.self_and_descendants : 
      [teammate.organization, teammate.organization.parent].compact
    
    teammate.person.huddle_participants
             .joins(huddle: :huddle_playbook)
             .where(huddle_playbooks: { organization_id: organizations_to_check })
             .exists?
  end

  def has_active_employment_tenure?
    teammate.employment_tenures.active.exists?(company: teammate.organization)
  end
end






