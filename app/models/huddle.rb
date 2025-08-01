class Huddle < ApplicationRecord
  # Associations
  belongs_to :organization
  belongs_to :huddle_playbook, optional: true
  has_many :huddle_participants, dependent: :destroy
  has_many :participants, through: :huddle_participants, source: :person
  has_many :huddle_feedbacks, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy
  
  # Validations
  validates :started_at, presence: true
  validate :unique_playbook_per_day

  
  # Scopes
  scope :active, -> { 
    where('expires_at > ?', Time.current)
  }
  scope :recent, -> { order(started_at: :desc) }
  scope :participated_by, ->(person) {
    joins(:huddle_participants).where(huddle_participants: { person: person })
  }
  
  # Instance methods
  def huddle_display_day
    started_at.strftime('%B %d, %Y')
  end

  def display_name_without_organization
    playbook_alias = huddle_playbook&.special_session_name
    playbook_alias.present? ? "#{huddle_display_day} - #{playbook_alias}" : huddle_display_day
  end
  
  def display_name
    "#{organization.display_name} - #{display_name_without_organization}"
  end

  def slug
    "#{organization.name.parameterize}_#{started_at.strftime('%Y-%m-%d')}"
  end
  
  def closed?
    # Huddle closes 24 hours after it was started
    expires_at < Time.current
  end
  
  def slack_channel
    huddle_playbook&.slack_channel_or_organization_default
  end

  def slack_configured?
    slack_configuration.present?
  end

  def slack_configuration
    huddle_playbook&.slack_configuration
  end

  def has_slack_announcement?
    notifications.announcements.successful.exists?
  end

  def has_slack_summary?
    notifications.summaries.successful.exists?
  end

  def slack_announcement_url
    announcement = notifications.announcements.successful.first
    announcement&.slack_url
  end

  def slack_announcement_notification
    notifications.announcements.successful.first
  end


  
  def department_head
    organization.department_head
  end
  
  def facilitators
    huddle_participants.facilitators.includes(:person)
  end
  
  def department_head_name
    dept_head = department_head
    dept_head&.display_name || 'Department Head'
  end
  
  def facilitator_names
    facilitators.map { |p| p.person.display_name }
  end
  
  def nat_20_score
    return nil if huddle_feedbacks.empty?
    
    total_score = huddle_feedbacks.sum do |feedback|
      feedback.informed_rating + feedback.connected_rating + 
      feedback.goals_rating + feedback.valuable_rating
    end
    
    (total_score.to_f / huddle_feedbacks.count).round(1)
  end
  
  def feedback_anonymous?
    huddle_feedbacks.any?(&:anonymous)
  end

  def participation_rate
    return 0 if huddle_participants.empty?
    (huddle_feedbacks.count.to_f / huddle_participants.count * 100).round(0)
  end

  def average_rating_by_category
    return {} if huddle_feedbacks.empty?
    
    {
      informed: huddle_feedbacks.average(:informed_rating).round(1),
      connected: huddle_feedbacks.average(:connected_rating).round(1),
      goals: huddle_feedbacks.average(:goals_rating).round(1),
      valuable: huddle_feedbacks.average(:valuable_rating).round(1)
    }
  end

  def feedback_insights
    return [] if huddle_feedbacks.empty?
    
    insights = []
    
    # Check for common themes in appreciation
    appreciations = huddle_feedbacks.where.not(appreciation: [nil, '']).pluck(:appreciation)
    if appreciations.any?
      insights << "Participants shared #{appreciations.count} positive feedback items"
    end
    
    # Check for improvement suggestions
    suggestions = huddle_feedbacks.where.not(change_suggestion: [nil, '']).pluck(:change_suggestion)
    if suggestions.any?
      insights << "Participants provided #{suggestions.count} improvement suggestions"
    end

    # Check participation rate
    if participation_rate < 50
      insights << "Low participation rate (#{participation_rate}%) - consider follow-up"
    elsif participation_rate >= 80
      insights << "High participation rate (#{participation_rate}%) - great engagement!"
    end
    
    insights
  end

  def team_conflict_style_distribution
    return {} if huddle_feedbacks.empty?
    
    styles = huddle_feedbacks.where.not(team_conflict_style: [nil, '']).pluck(:team_conflict_style)
    distribution = styles.tally
    
    # Sort by the desired order: Collaborative first, Avoiding last
    # Only include styles that actually appear in the feedback
    sorted_distribution = {}
    all_conflict_styles.each do |style|
      if distribution[style] && distribution[style] > 0
        sorted_distribution[style] = distribution[style]
      end
    end
    
    sorted_distribution
  end

  def personal_conflict_style_distribution
    return {} if huddle_feedbacks.empty?
    
    styles = huddle_feedbacks.where.not(personal_conflict_style: [nil, '']).pluck(:personal_conflict_style)
    distribution = styles.tally
    
    # Sort by the desired order: Collaborative first, Avoiding last
    # Only include styles that actually appear in the feedback
    sorted_distribution = {}
    all_conflict_styles.each do |style|
      if distribution[style] && distribution[style] > 0
        sorted_distribution[style] = distribution[style]
      end
    end
    
    sorted_distribution
  end

  def all_conflict_styles
    [
      'Collaborative',
      'Competing', 
      'Compromising',
      'Accommodating',
      'Avoiding'
    ]
  end
  
    private
  
  def unique_playbook_per_day
    return unless huddle_playbook_id && started_at
    
    # Check for existing huddles with the same playbook within 24 hours
    existing_huddle = Huddle.where(
      huddle_playbook_id: huddle_playbook_id
    ).where(
      "started_at BETWEEN ? AND ?", 
      started_at - 24.hours, 
      started_at + 24.hours
    ).where.not(id: id).first
    
    if existing_huddle
      errors.add(:base, "A huddle with this playbook already exists within 24 hours")
    end
  end
end 