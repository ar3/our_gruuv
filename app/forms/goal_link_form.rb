class GoalLinkForm < Reform::Form
  # Define form properties - Reform handles Rails integration automatically
  property :this_goal_id
  property :that_goal_id
  property :link_type
  property :metadata
  
  # Virtual properties
  property :metadata_notes, virtual: true
  property :link_direction, virtual: true # :outgoing or :incoming
  property :bulk_goal_titles, virtual: true # text area input, one per line
  property :bulk_create_mode, virtual: true # boolean
  
  # Access to current context (set by controller)
  attr_accessor :organization, :current_person, :current_teammate, :linking_goal
  
  # Use ActiveModel validations
  validates :link_type, presence: true
  validates :link_direction, presence: true, inclusion: { in: %w[outgoing incoming] }
  validate :validate_goal_selection
  validate :validate_bulk_titles
  validate :no_self_linking, unless: :bulk_create_mode?
  validate :no_circular_dependencies, unless: :bulk_create_mode?
  validate :uniqueness_of_link, unless: :bulk_create_mode?
  validate :link_type_inclusion
  
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
      # Incoming: this_goal_id comes from selected goal, that_goal_id is the linking goal
      model.this_goal_id = this_goal_id
      model.that_goal_id = linking_goal.id
    else # outgoing
      # Outgoing: this_goal_id is the linking goal, that_goal_id comes from selected goal
      model.this_goal_id = linking_goal.id
      model.that_goal_id = that_goal_id
    end
    
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
  
  def save_bulk_goals
    titles = bulk_goal_titles.to_s.split("\n").map(&:strip).reject(&:blank?)
    return false if titles.empty?
    
    service = Goals::BulkCreateService.new(
      organization,
      current_person,
      current_teammate,
      linking_goal,
      link_direction.to_sym,
      titles,
      link_type
    )
    
    if service.call
      true
    else
      service.errors.each { |error| errors.add(:base, error) }
      false
    end
  end
  
  def bulk_create_mode?
    bulk_create_mode == true || bulk_create_mode == 'true' || bulk_create_mode == '1'
  end
  
  def validate_goal_selection
    return if bulk_create_mode?
    
    if link_direction == 'incoming'
      errors.add(:this_goal_id, "can't be blank") if this_goal_id.blank?
    else
      errors.add(:that_goal_id, "can't be blank") if that_goal_id.blank?
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
      return unless this_goal_id && linking_goal
      
      if this_goal_id.to_i == linking_goal.id
        errors.add(:base, "cannot link a goal to itself")
      end
    else
      return unless that_goal_id && linking_goal
      
      if that_goal_id.to_i == linking_goal.id
        errors.add(:base, "cannot link a goal to itself")
      end
    end
  end
  
  def no_circular_dependencies
    if link_direction == 'incoming'
      return unless this_goal_id && linking_goal
      
      this_goal = Goal.find_by(id: this_goal_id)
      return unless this_goal
      
      if creates_cycle?(this_goal, linking_goal)
        errors.add(:base, "This link would create a circular dependency")
      end
    else
      return unless that_goal_id && linking_goal
      
      that_goal = Goal.find_by(id: that_goal_id)
      return unless that_goal
      
      if creates_cycle?(linking_goal, that_goal)
        errors.add(:base, "This link would create a circular dependency")
      end
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
    if link_direction == 'incoming'
      return unless this_goal_id && linking_goal && link_type
      
      existing = GoalLink.where(
        this_goal_id: this_goal_id,
        that_goal_id: linking_goal.id,
        link_type: link_type
      ).where.not(id: model.id).exists?
      
      if existing
        errors.add(:base, "link already exists")
      end
    else
      return unless that_goal_id && linking_goal && link_type
      
      existing = GoalLink.where(
        this_goal_id: linking_goal.id,
        that_goal_id: that_goal_id,
        link_type: link_type
      ).where.not(id: model.id).exists?
      
      if existing
        errors.add(:base, "link already exists")
      end
    end
  end
  
  def link_type_inclusion
    return unless link_type
    
    unless GoalLink.link_types.key?(link_type)
      errors.add(:link_type, 'is not included in the list')
    end
  end
end

