module Goals
  class BulkCreateService
    attr_reader :organization, :current_person, :current_teammate, :linking_goal, 
                :link_direction, :goal_titles, :goal_type, :created_goals, :errors, :metadata, :parsed_goals

    def initialize(organization, current_person, current_teammate, linking_goal, link_direction, goal_titles, goal_type = nil, metadata = nil, parsed_goals: nil)
      @organization = organization
      @current_person = current_person
      @current_teammate = current_teammate
      @linking_goal = linking_goal
      @link_direction = link_direction.to_sym
      @goal_titles = goal_titles.is_a?(Array) ? goal_titles.reject(&:blank?) : []
      @goal_type = goal_type
      @metadata = metadata
      @parsed_goals = parsed_goals || []
      @created_goals = []
      @errors = []
    end

    def call
      if parsed_goals.any?
        return false if parsed_goals.empty?
        return create_from_parsed_goals
      else
        return false if goal_titles.empty?
        return create_from_titles
      end
    end

    private

    def create_from_parsed_goals
      Goal.transaction do
        created_goal_map = {} # Maps parent_index to created Goal objects

        parsed_goals.each_with_index do |parsed_goal, index|
          goal = create_goal_from_parsed(parsed_goal)
          if goal.persisted?
            created_goals << goal
            created_goal_map[index] = goal

            # If this goal has a parent_index, it's a sub - link only to parent dom
            if parsed_goal[:parent_index].present?
              parent_goal = created_goal_map[parsed_goal[:parent_index]]
              if parent_goal
                parent_link_result = create_parent_link(parent_goal, goal)
                unless parent_link_result
                  errors << "Failed to create parent link for goal '#{parsed_goal[:title]}'"
                end
              else
                errors << "Parent goal not found for '#{parsed_goal[:title]}'"
              end
            else
              # This is a dom - link to linking_goal (based on link_direction)
              link_result = create_link_for_goal(goal)
              unless link_result
                errors << "Failed to create link for goal '#{parsed_goal[:title]}'"
              end
            end
          else
            errors << "Failed to create goal '#{parsed_goal[:title]}': #{goal.errors.full_messages.join(', ')}"
          end
        end

        if errors.any?
          raise ActiveRecord::Rollback
        end
      end

      errors.empty?
    end

    def create_from_titles
      Goal.transaction do
        goal_titles.each do |title|
          goal = create_goal_from_title(title)
          if goal.persisted?
            created_goals << goal
            link_result = create_link_for_goal(goal)
            unless link_result
              errors << "Failed to create link for goal '#{title}'"
            end
          else
            errors << "Failed to create goal '#{title}': #{goal.errors.full_messages.join(', ')}"
          end
        end

        if errors.any?
          raise ActiveRecord::Rollback
        end
      end

      errors.empty?
    end

    private

    def create_goal_from_parsed(parsed_goal)
      goal = Goal.new(
        title: parsed_goal[:title].to_s.strip,
        description: '',
        goal_type: parsed_goal[:goal_type] || determine_goal_type,
        privacy_level: linking_goal.privacy_level,
        creator: current_teammate
      )
      
      owner_teammate = linking_goal.owner
      goal.owner_type = owner_teammate.is_a?(CompanyTeammate) ? 'CompanyTeammate' : owner_teammate.class.name
      goal.owner_id = owner_teammate.id

      # Set most_likely_target_date based on parent goal (only for non-objective goals)
      goal_type_value = parsed_goal[:goal_type] || determine_goal_type
      if goal_type_value != 'inspirational_objective'
        # Non-objective goals should have target dates
        if linking_goal.most_likely_target_date.present?
          goal.most_likely_target_date = linking_goal.most_likely_target_date
        else
          goal.most_likely_target_date = Date.current + 90.days
        end
      end

      # Don't set earliest or latest target dates
      goal.earliest_target_date = nil
      goal.latest_target_date = nil

      goal.save
      goal
    end

    def create_goal_from_title(title)
      goal = Goal.new(
        title: title.strip,
        description: '',
        goal_type: determine_goal_type,
        privacy_level: linking_goal.privacy_level,
        creator: current_teammate
      )

      owner_teammate = linking_goal.owner
      goal.owner_type = owner_teammate.is_a?(CompanyTeammate) ? 'CompanyTeammate' : owner_teammate.class.name
      goal.owner_id = owner_teammate.id

      # Set most_likely_target_date based on parent goal (only for non-objective goals)
      goal_type_value = determine_goal_type
      if goal_type_value != 'inspirational_objective'
        # Non-objective goals should have target dates
        if linking_goal.most_likely_target_date.present?
          goal.most_likely_target_date = linking_goal.most_likely_target_date
        else
          goal.most_likely_target_date = Date.current + 90.days
        end
      end

      # Don't set earliest or latest target dates
      goal.earliest_target_date = nil
      goal.latest_target_date = nil

      goal.save
      goal
    end

    def determine_goal_type
      if goal_type.present?
        goal_type
      elsif link_direction == :incoming
        'inspirational_objective'
      else # :outgoing
        'stepping_stone_activity'
      end
    end

    def create_link_for_goal(goal)
      link = if link_direction == :incoming
        # Incoming: created goal becomes the parent, linking goal becomes the child
        GoalLink.new(
          parent: goal,
          child: linking_goal
        )
      else # :outgoing
        # Outgoing: linking goal becomes the parent, created goal becomes the child
        GoalLink.new(
          parent: linking_goal,
          child: goal
        )
      end
      
      # Set metadata if provided
      if metadata.present?
        link.metadata = metadata
      end
      
      # Explicitly skip circular dependency check for bulk creation
      # Goals are created in the same transaction, so cycles can't exist yet
      link.skip_circular_dependency_check = true
      
      if link.save
        true
      else
        errors << "Failed to create link for goal '#{goal.title}': #{link.errors.full_messages.join(', ')}"
        false
      end
    rescue => e
      errors << "Failed to create link: #{e.message}"
      false
    end

    def create_parent_link(parent_goal, child_goal)
      link = GoalLink.new(
        parent: parent_goal,
        child: child_goal
      )
      
      # Set metadata if provided
      if metadata.present?
        link.metadata = metadata
      end
      
      # Explicitly skip circular dependency check for bulk creation
      link.skip_circular_dependency_check = true
      
      if link.save
        true
      else
        errors << "Failed to create parent link for goal '#{child_goal.title}': #{link.errors.full_messages.join(', ')}"
        false
      end
    rescue => e
      errors << "Failed to create parent link: #{e.message}"
      false
    end
  end
end





