class GoalLinkForm < Reform::Form
  # Define form properties - Reform handles Rails integration automatically
  property :parent_id
  property :child_id
  property :metadata
  
  # Virtual properties
  property :metadata_notes, virtual: true
  property :link_direction, virtual: true # :outgoing or :incoming
  property :bulk_goal_titles, virtual: true # text area input, one per line
  property :bulk_create_mode, virtual: true # boolean
  
  # Access to current context (set by controller)
  attr_accessor :organization, :current_person, :current_teammate, :linking_goal, :bulk_create_service
  
  # Use ActiveModel validations
  validates :link_direction, presence: true, inclusion: { in: %w[outgoing incoming] }
  validate :validate_goal_selection
  validate :validate_bulk_titles
  validate :no_self_linking, unless: :bulk_create_mode?
  validate :no_circular_dependencies, unless: :bulk_create_mode?
  validate :uniqueness_of_link, unless: :bulk_create_mode?
  
  # Reform automatically handles save - we just need to customize the logic
  def save
    return false unless valid?
    
    if bulk_create_mode?
      return save_bulk_goals
    else
      return save_single_link
    end
  end
  
  private
  
  def save_single_link
    # Set the goal associations based on direction
    if link_direction == 'incoming'
      # Incoming: selected goal becomes the parent, linking goal becomes the child
      model.parent_id = parent_id
      model.child_id = linking_goal.id
    else # outgoing
      # Outgoing: linking goal becomes the parent, selected goal becomes the child
      model.parent_id = linking_goal.id
      model.child_id = child_id
    end
    
    # Handle metadata - either from metadata param or metadata_notes virtual property
    if metadata_notes.present?
      model.metadata = { notes: metadata_notes }
    elsif metadata.present?
      model.metadata = metadata
    end
    
    # Save the model
    model.save
  end
  
  def save_bulk_goals
    titles = bulk_goal_titles.to_s.split("\n").map(&:strip).reject(&:blank?)
    return false if titles.empty?
    
    @bulk_create_service = Goals::BulkCreateService.new(
      organization,
      current_person,
      current_teammate,
      linking_goal,
      link_direction.to_sym,
      titles
    )
    
    if @bulk_create_service.call
      true
    else
      @bulk_create_service.errors.each { |error| errors.add(:base, error) }
      false
    end
  end
  
  def bulk_create_mode?
    bulk_create_mode == true || bulk_create_mode == 'true' || bulk_create_mode == '1'
  end
  
  def validate_goal_selection
    return if bulk_create_mode?
    
    if link_direction == 'incoming'
      errors.add(:parent_id, "can't be blank") if parent_id.blank?
    else
      errors.add(:child_id, "can't be blank") if child_id.blank?
    end
  end
  
  def validate_bulk_titles
    return unless bulk_create_mode?
    
    if bulk_goal_titles.blank?
      errors.add(:bulk_goal_titles, "can't be blank")
    else
      titles = bulk_goal_titles.to_s.split("\n").map(&:strip).reject(&:blank?)
      if titles.empty?
        errors.add(:bulk_goal_titles, "must contain at least one goal title")
      end
    end
  end
  
  def no_self_linking
    if link_direction == 'incoming'
      return unless parent_id && linking_goal
      
      if parent_id.to_i == linking_goal.id
        errors.add(:base, "cannot link a goal to itself")
      end
    else
      return unless child_id && linking_goal
      
      if child_id.to_i == linking_goal.id
        errors.add(:base, "cannot link a goal to itself")
      end
    end
  end
  
  def no_circular_dependencies
    if link_direction == 'incoming'
      return unless parent_id && linking_goal
      
      parent_goal = Goal.find_by(id: parent_id)
      return unless parent_goal
      
      if creates_cycle?(parent_goal, linking_goal)
        errors.add(:base, "This link would create a circular dependency")
      end
    else
      return unless child_id && linking_goal
      
      child_goal = Goal.find_by(id: child_id)
      return unless child_goal
      
      if creates_cycle?(linking_goal, child_goal)
        errors.add(:base, "This link would create a circular dependency")
      end
    end
  end
  
  def creates_cycle?(parent_goal, child_goal)
    # BFS to check if child_goal eventually links back to parent_goal
    visited = Set.new
    queue = [child_goal]
    
    while queue.any?
      current = queue.shift
      return true if current.id == parent_goal.id
      
      next if visited.include?(current.id)
      visited.add(current.id)
      
      # Follow outgoing links from current goal (goals where current is the parent)
      current.outgoing_links.each do |link|
        queue << link.child
      end
    end
    
    false
  end
  
  def uniqueness_of_link
    if link_direction == 'incoming'
      return unless parent_id && linking_goal
      
      existing = GoalLink.where(
        parent_id: parent_id,
        child_id: linking_goal.id
      ).where.not(id: model.id).exists?
      
      if existing
        errors.add(:base, "link already exists")
      end
    else
      return unless child_id && linking_goal
      
      existing = GoalLink.where(
        parent_id: linking_goal.id,
        child_id: child_id
      ).where.not(id: model.id).exists?
      
      if existing
        errors.add(:base, "link already exists")
      end
    end
  end
end

