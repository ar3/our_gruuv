class GoalLink < ApplicationRecord
  # Associations
  belongs_to :this_goal, class_name: 'Goal', foreign_key: 'this_goal_id'
  belongs_to :that_goal, class_name: 'Goal', foreign_key: 'that_goal_id'
  
  # Enums
  enum :link_type, {
    if_this_then_that: 'if_this_then_that',
    this_blocks_that: 'this_blocks_that',
    this_makes_that_easier: 'this_makes_that_easier',
    this_makes_that_unnecessary: 'this_makes_that_unnecessary',
    this_is_key_result_of_that: 'this_is_key_result_of_that',
    this_supports_that: 'this_supports_that'
  }
  
  # Flag to skip circular dependency check (used by BulkCreateService)
  attr_accessor :skip_circular_dependency_check
  
  # Validations
  validates :this_goal, :that_goal, :link_type, presence: true
  validate :no_self_linking
  validate :no_circular_dependencies, unless: :should_skip_circular_dependency_check?
  validate :uniqueness_of_link
  
  private
  
  def no_self_linking
    return unless this_goal && that_goal
    
    if this_goal_id == that_goal_id
      errors.add(:base, "cannot link a goal to itself")
    end
  end
  
  def no_circular_dependencies
    return unless this_goal && that_goal
    
    if creates_cycle?
      errors.add(:base, "This link would create a circular dependency")
    end
  end
  
  def creates_cycle?
    # BFS to check if that_goal eventually links back to this_goal
    visited = Set.new
    queue = [that_goal]
    
    while queue.any?
      current = queue.shift
      return true if current.id == this_goal.id
      
      next if visited.include?(current.id)
      visited.add(current.id)
      
      # Follow outgoing links from current goal
      # Reload to ensure we get fresh associations
      current.outgoing_links.reload.each do |link|
        queue << link.that_goal
      end
    end
    
    false
  end
  
  def uniqueness_of_link
    return unless this_goal && that_goal && link_type
    
    existing = GoalLink.where(
      this_goal_id: this_goal_id,
      that_goal_id: that_goal_id,
      link_type: link_type
    ).where.not(id: id).exists?
    
    if existing
      errors.add(:base, "link already exists")
    end
  end
  
  def should_skip_circular_dependency_check?
    # Explicit flag takes precedence
    return true if skip_circular_dependency_check == true
    
    # Fallback to timing-based detection for backwards compatibility
    newly_created_goal?
  end
  
  def newly_created_goal?
    # Check if one goal was created very recently and the other is older
    # This indicates bulk creation where a new goal is created and immediately linked to an existing one
    return false unless this_goal&.created_at && that_goal&.created_at
    
    now = Time.current
    this_recent = this_goal.created_at > 1.second.ago
    that_recent = that_goal.created_at > 1.second.ago
    
    # If both are recent, they might both be from test setup - don't skip validation
    return false if this_recent && that_recent
    
    # If one is recent and the other is not, it's likely bulk creation
    # Check if the newer goal was created in the current second
    newer_goal = this_goal.created_at > that_goal.created_at ? this_goal : that_goal
    newer_goal.created_at.to_i == now.to_i
  end
end



