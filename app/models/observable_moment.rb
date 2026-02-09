class ObservableMoment < ApplicationRecord
  belongs_to :momentable, polymorphic: true
  belongs_to :company, class_name: 'Organization'
  belongs_to :created_by, class_name: 'Person'
  belongs_to :primary_potential_observer, class_name: 'CompanyTeammate'
  belongs_to :processed_by_teammate, class_name: 'CompanyTeammate', optional: true
  
  has_many :observations, dependent: :nullify
  
  enum :moment_type, {
    new_hire: 'new_hire',
    seat_change: 'seat_change',
    ability_milestone: 'ability_milestone',
    check_in_completed: 'check_in_completed',
    goal_check_in: 'goal_check_in',
    birthday: 'birthday',
    work_anniversary: 'work_anniversary'
  }
  
  validates :momentable_type, :momentable_id, :moment_type, :company, :created_by, 
            :primary_potential_observer, :occurred_at, presence: true
  
  scope :for_company, ->(company) { where(company: company) }
  scope :by_type, ->(type) { where(moment_type: type) }
  scope :recent, -> { order(occurred_at: :desc) }
  scope :pending, -> { where(processed_at: nil) }
  scope :processed, -> { where.not(processed_at: nil) }
  scope :for_observer, ->(teammate) { 
    where(primary_potential_observer: teammate, processed_at: nil) 
  }
  
  def processed?
    processed_at.present?
  end
  
  def observed?
    observations.exists?
  end
  
  def ignored?
    processed? && !observed?
  end
  
  def display_name
    case moment_type
    when 'new_hire'
      person = associated_person
      "New Hire: #{person&.display_name || 'Unknown'}"
    when 'seat_change'
      person = associated_person
      "Seat Change: #{person&.display_name || 'Unknown'}"
    when 'ability_milestone'
      milestone = momentable
      "#{milestone&.ability&.name || 'Unknown'} Milestone Level #{milestone&.milestone_level || '?'}"
    when 'check_in_completed'
      check_in = momentable
      check_in_type = check_in.class.name.underscore.humanize
      "#{check_in_type} Check-In Completed"
    when 'goal_check_in'
      goal_check_in = momentable
      goal = goal_check_in&.goal
      "Goal Check-In: #{goal&.title || 'Unknown Goal'}"
    when 'birthday'
      person = associated_person
      "Birthday: #{person&.display_name || 'Unknown'}"
    when 'work_anniversary'
      person = associated_person
      "Work Anniversary: #{person&.display_name || 'Unknown'}"
    else
      "#{moment_type.humanize} Moment"
    end
  end
  
  def description
    case moment_type
    when 'new_hire'
      tenure = momentable
      person = tenure&.teammate&.person
      position = tenure&.position
        "Welcome #{person&.display_name || 'new team member'} to the team as #{position&.display_name || 'a new position'}!"
    when 'seat_change'
      tenure = momentable
      person = tenure&.teammate&.person
      old_position = metadata['old_position_name']
      new_position = tenure&.position&.display_name
      if old_position && new_position
        "#{person&.display_name || 'Team member'} changed from #{old_position} to #{new_position}"
      else
        "#{person&.display_name || 'Team member'} changed positions"
      end
    when 'ability_milestone'
      milestone = momentable
      person = milestone&.teammate&.person
      ability = milestone&.ability
      level = milestone&.milestone_level
      "#{person&.display_name || 'Team member'} achieved #{ability&.name || 'an ability'} milestone level #{level || '?'}"
    when 'check_in_completed'
      check_in = momentable
      person = check_in&.teammate&.person
      rating = metadata['official_rating']
      "#{person&.display_name || 'Team member'} completed their check-in with rating: #{rating || 'N/A'}"
    when 'goal_check_in'
      goal_check_in = momentable
      goal = goal_check_in&.goal
      person = goal&.owner&.person if goal&.owner&.respond_to?(:person)
      confidence = metadata['confidence_percentage']
      "#{person&.display_name || 'Team member'} updated goal '#{goal&.title || 'Unknown'}' with #{confidence || '?'}% confidence"
    when 'birthday'
      person = associated_person
      "Celebrate #{person&.display_name || 'team member'}'s birthday!"
    when 'work_anniversary'
      person = associated_person
      "Celebrate #{person&.display_name || 'team member'}'s work anniversary!"
    else
      "#{moment_type.humanize} occurred on #{occurred_at.strftime('%B %d, %Y')}"
    end
  end
  
  def associated_person
    case moment_type
    when 'new_hire', 'seat_change'
      momentable&.teammate&.person
    when 'ability_milestone'
      momentable&.teammate&.person
    when 'check_in_completed'
      momentable&.teammate&.person
    when 'goal_check_in'
      goal = momentable&.goal
      if goal&.owner&.respond_to?(:person)
        goal.owner.person
      elsif goal&.owner&.respond_to?(:teammate)
        goal.owner.teammate&.person
      end
    when 'birthday', 'work_anniversary'
      momentable&.person
    end
  end
  
  def associated_teammate
    case moment_type
    when 'new_hire', 'seat_change'
      momentable&.teammate
    when 'ability_milestone'
      momentable&.teammate
    when 'check_in_completed'
      momentable&.teammate
    when 'goal_check_in'
      goal = momentable&.goal
      if goal&.owner&.respond_to?(:teammate)
        goal.owner.teammate
      end
    when 'birthday', 'work_anniversary'
      momentable
    end
  end
  
  def reassign_to(teammate)
    update!(primary_potential_observer: teammate)
  end
end

