# frozen_string_literal: true

module Goals
  # Create a draft goal for the Bulk Edit sheet (title + owner + type minimum).
  # Optional parent_goal creates an outgoing GoalLink from parent → new child.
  class BulkEditCreate
    Result = Struct.new(:ok?, :goal, :errors, keyword_init: true)

    def self.call(...) = new(...).call

    def initialize(organization:, current_person:, current_teammate:, attrs:, parent_goal: nil)
      @organization = organization
      @current_person = current_person
      @current_teammate = current_teammate
      @attrs = attrs.to_h.with_indifferent_access
      @parent_goal = parent_goal
    end

    def call
      company = @organization.root_company || @organization
      goal = Goal.new(company: company)
      form = GoalForm.new(goal)
      form.current_person = @current_person
      form.current_teammate = @current_teammate

      owner_value = @attrs[:owner_id].presence || default_owner_value
      privacy = privacy_for_owner_value(owner_value)

      payload = {
        title: @attrs[:title].to_s.strip,
        goal_type: @attrs[:goal_type].presence || "inspirational_objective",
        description: @attrs[:description].to_s,
        most_likely_target_date: @attrs[:most_likely_target_date].presence,
        owner_id: owner_value,
        privacy_level: privacy,
        edit_check_in_permission: "anyone_who_can_view"
      }

      PaperTrail.request.whodunnit = @current_teammate.id.to_s

      unless form.validate(payload) && form.save
        return Result.new(ok?: false, goal: goal, errors: form.errors.full_messages)
      end

      if @parent_goal
        link = GoalLink.new(parent_id: @parent_goal.id, child_id: goal.id)
        unless link.save
          goal.soft_delete! if goal.respond_to?(:soft_delete!)
          return Result.new(ok?: false, goal: goal, errors: link.errors.full_messages.presence || ["Could not link child goal"])
        end
      end

      EngagementHealth.schedule_refresh_for_goal(goal)
      Result.new(ok?: true, goal: goal, errors: [])
    end

    private

    def default_owner_value
      "CompanyTeammate_#{@current_teammate.id}"
    end

    def privacy_for_owner_value(owner_value)
      type = owner_value.to_s.split("_", 2).first
      case type
      when "Team", "Department", "Company", "Organization"
        "everyone_in_company"
      else
        "only_creator_owner_and_managers"
      end
    end
  end
end
