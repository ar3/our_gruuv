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
  
  # Validations
  validates :this_goal, :that_goal, :link_type, presence: true
  validate :no_self_linking
  validate :no_circular_dependencies
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
      current.outgoing_links.each do |link|
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
end


