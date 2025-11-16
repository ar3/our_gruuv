module Goals
  class BulkCreateService
    attr_reader :organization, :current_person, :current_teammate, :linking_goal, 
                :link_direction, :goal_titles, :goal_type, :created_goals, :errors

    def initialize(organization, current_person, current_teammate, linking_goal, link_direction, goal_titles, goal_type = nil)
      @organization = organization
      @current_person = current_person
      @current_teammate = current_teammate
      @linking_goal = linking_goal
      @link_direction = link_direction.to_sym
      @goal_titles = goal_titles.reject(&:blank?)
      @goal_type = goal_type
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
        description: title.strip,
        goal_type: determine_goal_type,
        owner: linking_goal.owner,
        privacy_level: linking_goal.privacy_level,
        creator: current_teammate
      )

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





