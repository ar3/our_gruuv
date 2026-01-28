module Goals
  class BulkCreateUnlinkedService
    attr_reader :organization, :current_person, :current_teammate, :owner,
                :parsed_goals, :default_goal_type, :privacy_level, :created_goals, :errors

    # owner: polymorphic (CompanyTeammate or Organization) - who owns the created goals
    def initialize(organization, current_person, current_teammate, owner, parsed_goals, default_goal_type: 'quantitative_key_result', privacy_level: 'only_creator_owner_and_managers')
      @organization = organization
      @current_person = current_person
      @current_teammate = current_teammate
      @owner = owner
      @parsed_goals = parsed_goals || []
      @default_goal_type = default_goal_type
      @privacy_level = privacy_level
      @created_goals = []
      @errors = []
    end

    def call
      return false if parsed_goals.empty?

      Goal.transaction do
        created_goal_map = {}

        parsed_goals.each_with_index do |parsed_goal, index|
          goal = create_goal_from_parsed(parsed_goal)
          if goal.persisted?
            created_goals << goal
            created_goal_map[index] = goal

            if parsed_goal[:parent_index].present?
              parent_goal = created_goal_map[parsed_goal[:parent_index]]
              if parent_goal
                unless create_parent_link(parent_goal, goal)
                  errors << "Failed to create parent link for goal '#{parsed_goal[:title]}'"
                end
              else
                errors << "Parent goal not found for '#{parsed_goal[:title]}'"
              end
            end
          else
            errors << "Failed to create goal '#{parsed_goal[:title]}': #{goal.errors.full_messages.join(', ')}"
          end
        end

        raise ActiveRecord::Rollback if errors.any?
      end

      errors.empty?
    end

    private

    def company
      @company ||= organization.root_company || organization
    end

    def create_goal_from_parsed(parsed_goal)
      goal_type_value = parsed_goal[:goal_type] || default_goal_type

      goal = Goal.new(
        title: parsed_goal[:title].to_s.strip,
        description: '',
        goal_type: goal_type_value,
        privacy_level: privacy_level,
        creator: current_teammate,
        company: company
      )

      set_owner_on_goal(goal, owner)

      if goal_type_value != 'inspirational_objective'
        goal.most_likely_target_date = Date.current + 90.days
      end

      goal.earliest_target_date = nil
      goal.latest_target_date = nil

      goal.save
      goal
    end

    def set_owner_on_goal(goal, owner_record)
      if owner_record.respond_to?(:type) && owner_record.type == 'CompanyTeammate'
        goal.owner_type = 'CompanyTeammate'
      elsif owner_record.is_a?(CompanyTeammate)
        goal.owner_type = 'CompanyTeammate'
      elsif owner_record.is_a?(Organization)
        # Goal model expects owner_type 'Organization' for Company/Department/Team (polymorphic base class)
        goal.owner_type = 'Organization'
      else
        goal.owner_type = owner_record.class.base_class.name
      end
      goal.owner_id = owner_record.id
    end

    def create_parent_link(parent_goal, child_goal)
      link = GoalLink.new(
        parent: parent_goal,
        child: child_goal
      )
      link.skip_circular_dependency_check = true

      if link.save
        true
      else
        errors << "Failed to create parent link for goal '#{child_goal.title}': #{link.errors.full_messages.join(', ')}"
        false
      end
    rescue StandardError => e
      errors << "Failed to create parent link: #{e.message}"
      false
    end
  end
end
