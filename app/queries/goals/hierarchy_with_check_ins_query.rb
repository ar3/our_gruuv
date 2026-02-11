module Goals
  class HierarchyWithCheckInsQuery
    def initialize(goals:, current_person:, organization:)
      @goals = goals.to_a
      @goal_ids = @goals.map(&:id).to_set
      @current_person = current_person
      @organization = organization
    end

    def call
      # Build basic hierarchy
      hierarchy = Goals::HierarchyQuery.new(goals: @goals).call
      
      # Load check-in data
      load_check_in_data
      
      # Load permissions
      load_permissions
      
      # Enrich nodes with check-in data
      root_goals = hierarchy[:root_goals].map do |goal|
        build_enriched_node(goal, hierarchy[:parent_child_map])
      end
      
      {
        root_goals: root_goals,
        parent_child_map: hierarchy[:parent_child_map],
        most_recent_check_ins_by_goal: @most_recent_check_ins_by_goal,
        current_week_check_ins_by_goal: @current_week_check_ins_by_goal,
        can_check_in_goals: @can_check_in_goals
      }
    end

    private

    attr_reader :goals, :goal_ids, :current_person, :organization

    def load_check_in_data
      current_week_start = Date.current.beginning_of_week(:monday)
      
      # Load most recent check-ins for each goal
      @most_recent_check_ins_by_goal = GoalCheckIn
        .where(goal_id: goal_ids)
        .includes(:confidence_reporter, :goal)
        .recent
        .group_by(&:goal_id)
        .transform_values { |check_ins| check_ins.first }
      
      # Load current week check-ins for each goal
      @current_week_check_ins_by_goal = GoalCheckIn
        .where(goal_id: goal_ids, check_in_week_start: current_week_start)
        .includes(:confidence_reporter)
        .index_by(&:goal_id)
    end

    def load_permissions
      # Check which goals the current person can add check-ins to.
      # Teammate-owned: only creator or owner. Team/department/company: if you can see, you can check-in.
      @can_check_in_goals = Set.new
      
      return unless current_person
      
      viewing_teammate = current_person.teammates.find_by(organization: organization)
      return unless viewing_teammate
      
      pundit_user = OpenStruct.new(user: viewing_teammate, impersonating_teammate: nil)
      goals.each do |goal|
        check_in_record = GoalCheckIn.new(goal: goal)
        if GoalCheckInPolicy.new(pundit_user, check_in_record).create?
          @can_check_in_goals.add(goal.id)
        end
      end
    end

    def build_enriched_node(goal, parent_child_map)
      children = (parent_child_map[goal.id] || []).compact
      
      enriched_children = children.map do |child|
        build_enriched_node(child, parent_child_map)
      end
      
      # Calculate counts
      direct_children_count = enriched_children.length
      total_descendants_count = direct_children_count + enriched_children.sum { |c| c[:total_descendants_count] }
      
      {
        goal: goal,
        children: enriched_children,
        direct_children_count: direct_children_count,
        total_descendants_count: total_descendants_count,
        most_recent_check_in: @most_recent_check_ins_by_goal[goal.id],
        current_week_check_in: @current_week_check_ins_by_goal[goal.id],
        can_check_in: @can_check_in_goals.include?(goal.id)
      }
    end
  end
end
