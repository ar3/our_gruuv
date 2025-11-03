module Goals
  class BulkCreateService
    attr_reader :organization, :current_person, :current_teammate, :linking_goal, 
                :link_direction, :goal_titles, :link_type, :created_goals, :errors

    def initialize(organization, current_person, current_teammate, linking_goal, link_direction, goal_titles, link_type)
      @organization = organization
      @current_person = current_person
      @current_teammate = current_teammate
      @linking_goal = linking_goal
      @link_direction = link_direction.to_sym
      @goal_titles = goal_titles.reject(&:blank?)
      @link_type = link_type
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
            create_link_for_goal(goal)
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

      # No due dates for bulk created goals
      goal.earliest_target_date = nil
      goal.most_likely_target_date = nil
      goal.latest_target_date = nil

      goal.save
      goal
    end

    def determine_goal_type
      if link_direction == :incoming
        'inspirational_objective'
      else # :outgoing
        'quantitative_key_result'
      end
    end

    def create_link_for_goal(goal)
      if link_direction == :incoming
        # Incoming: this_goal_id comes from the created goal, that_goal_id is the linking goal
        GoalLink.create!(
          this_goal: goal,
          that_goal: linking_goal,
          link_type: link_type
        )
      else # :outgoing
        # Outgoing: this_goal_id is the linking goal, that_goal_id comes from the created goal
        GoalLink.create!(
          this_goal: linking_goal,
          that_goal: goal,
          link_type: link_type
        )
      end
    end
  end
end

