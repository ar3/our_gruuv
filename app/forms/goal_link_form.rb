class GoalLinkForm < Reform::Form
  # Define form properties - Reform handles Rails integration automatically
  property :this_goal_id
  property :that_goal_id
  property :link_type
  property :metadata
  
  # Virtual property for metadata notes
  property :metadata_notes, virtual: true
  
  # Use ActiveModel validations
  validates :this_goal_id, presence: true
  validates :that_goal_id, presence: true
  validates :link_type, presence: true
  validate :no_self_linking
  validate :no_circular_dependencies
  validate :uniqueness_of_link
  validate :link_type_inclusion
  
  # Reform automatically handles save - we just need to customize the logic
  def save
    return false unless valid?
    
    # Set the goal associations
    model.this_goal_id = this_goal_id
    model.that_goal_id = that_goal_id
    model.link_type = link_type
    
    # Handle metadata - either from metadata param or metadata_notes virtual property
    if metadata_notes.present?
      model.metadata = { notes: metadata_notes }
    elsif metadata.present?
      model.metadata = metadata
    end
    
    # Save the model
    model.save
  end
  
  private
  
  def no_self_linking
    return unless this_goal_id && that_goal_id
    
    if this_goal_id == that_goal_id
      errors.add(:base, "cannot link a goal to itself")
    end
  end
  
  def no_circular_dependencies
    return unless this_goal_id && that_goal_id
    
    this_goal = Goal.find_by(id: this_goal_id)
    that_goal = Goal.find_by(id: that_goal_id)
    
    return unless this_goal && that_goal
    
    if creates_cycle?(this_goal, that_goal)
      errors.add(:base, "This link would create a circular dependency")
    end
  end
  
  def creates_cycle?(this_goal, that_goal)
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
    return unless this_goal_id && that_goal_id && link_type
    
    existing = GoalLink.where(
      this_goal_id: this_goal_id,
      that_goal_id: that_goal_id,
      link_type: link_type
    ).where.not(id: model.id).exists?
    
    if existing
      errors.add(:base, "link already exists")
    end
  end
  
  def link_type_inclusion
    return unless link_type
    
    unless GoalLink.link_types.key?(link_type)
      errors.add(:link_type, 'is not included in the list')
    end
  end
end

