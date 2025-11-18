module Goals
  class HierarchyQuery
    def initialize(goals:)
      @goals = goals.to_a
      @goal_ids = @goals.map(&:id).to_set
    end

    def call
      build_hierarchy
    end

    # Returns root goals (goals with no incoming links)
    def root_goals
      call[:root_goals]
    end

    # Returns a hash mapping goal_id => array of child goals
    def parent_child_map
      call[:parent_child_map]
    end

    # Returns all links used in building the hierarchy
    def links
      call[:links]
    end

    private

    attr_reader :goals, :goal_ids

    def build_hierarchy
      # Load all relevant links
      links = load_links
      
      # Build parent-child map
      parent_child_map = build_parent_child_map(links)
      
      # Find root goals (goals with no incoming links)
      root_goals = find_root_goals(links)

      {
        root_goals: root_goals,
        parent_child_map: parent_child_map,
        links: links
      }
    end

    def load_links
      # Only load links where both parent and child are in the goal_ids set
      # This ensures we only consider relationships within the collection
      GoalLink.where(parent_id: goal_ids)
              .where(child_id: goal_ids)
    end

    def build_parent_child_map(links)
      parent_child_map = {}
      
      goals.each do |goal|
        parent_child_map[goal.id] = []
      end

      # Load all goals referenced in links (including completed/deleted)
      referenced_goal_ids = (links.map(&:parent_id) + links.map(&:child_id)).uniq
      referenced_goals = Goal.where(id: referenced_goal_ids).index_by(&:id)

      links.each do |link|
        # parent_id is the parent, child_id is the child
        # Only include links where both parent and child are in our goal set
        if link.parent_id.in?(goal_ids) && link.child_id.in?(goal_ids)
          parent_child_map[link.parent_id] ||= []
          child_goal = referenced_goals[link.child_id]
          # Only add if child goal exists (filter out nil from associations)
          parent_child_map[link.parent_id] << child_goal if child_goal
        end
      end

      parent_child_map
    end

    def find_root_goals(links)
      goals_that_are_children = Set.new
      
      links.each do |link|
        # Goals that appear as child_id are children, not root
        # But only if BOTH parent and child are in the collection
        # Root goals are those with NO incoming links (no links where child_id == goal.id AND parent_id is in collection)
        if link.child_id.in?(goal_ids) && link.parent_id.in?(goal_ids)
          goals_that_are_children.add(link.child_id)
        end
      end

      # Root goals are those that are NOT children (have no incoming links from goals in the collection)
      goals.reject { |goal| goals_that_are_children.include?(goal.id) }
    end
  end
end

