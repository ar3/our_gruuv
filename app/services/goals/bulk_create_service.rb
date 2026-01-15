module Goals
  class BulkCreateService
    attr_reader :organization, :current_person, :current_teammate, :linking_goal, 
                :link_direction, :goal_titles, :goal_type, :created_goals, :errors, :metadata

    def initialize(organization, current_person, current_teammate, linking_goal, link_direction, goal_titles, goal_type = nil, metadata = nil)
      @organization = organization
      @current_person = current_person
      @current_teammate = current_teammate
      @linking_goal = linking_goal
      @link_direction = link_direction.to_sym
      @goal_titles = goal_titles.reject(&:blank?)
      @goal_type = goal_type
      @metadata = metadata
      @created_goals = []
      @errors = []
    end

    def call
      return false if goal_titles.empty?

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

    def create_goal_from_title(title)
      goal = Goal.new(
        title: title.strip,
        description: '',
        goal_type: determine_goal_type,
        privacy_level: linking_goal.privacy_level,
        creator: current_teammate
      )
      
      # Explicitly set owner_type and owner_id to preserve STI type
      # Rails polymorphic associations don't preserve STI types, so we need to set them explicitly
      owner_teammate = linking_goal.owner
      if owner_teammate.respond_to?(:type) && owner_teammate.type == 'CompanyTeammate'
        goal.owner_type = 'CompanyTeammate'
      elsif owner_teammate.is_a?(CompanyTeammate)
        goal.owner_type = 'CompanyTeammate'
      else
        goal.owner_type = owner_teammate.class.base_class.name
      end
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
  end
end





