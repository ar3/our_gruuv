# frozen_string_literal: true

# Shared create/destroy for polymorphic GoalAssociation under Assignment, Ability, Aspiration.
class Organizations::AssociableGoalAssociationsBaseController < Organizations::OrganizationNamespaceBaseController
  include AssociableGoalsHelper
  include Organizations::AssociableGoalFlowParams

  before_action :authenticate_person!
  before_action :set_associable
  before_action :set_goal_association, only: [:destroy]

  after_action :verify_authorized

  def create
    initial = GoalAssociation.new(associable: associable, goal: Goal.new)
    assign_goal_flow_teammate_from_params(initial)
    authorize initial, :create?

    goal_ids = Array(params[:goal_ids]).reject(&:blank?)
    # Preserve leading whitespace on each line — Goals::ParseService uses it for nesting depth.
    bulk_goal_text = params[:bulk_goal_titles].to_s
    bulk_has_lines = bulk_goal_text.split("\n", -1).any? { |line| line.strip.present? }

    if goal_ids.empty? && !bulk_has_lines
      redirect_to associable_goals_choose_manage_path(
        @organization,
        associable,
        **associable_goal_flow_query_params
      ),
                  alert: 'Please select at least one existing goal or provide at least one new goal title.'
      return
    end

    success_count = 0
    errors = []
    org_company = @organization.root_company || @organization
    current_teammate = current_person.teammates.find_by(organization: org_company)

    unless current_teammate.is_a?(CompanyTeammate)
      redirect_url = params[:return_url].presence || default_return_after_goal_association
      redirect_to redirect_url,
                  alert: 'You must be a company teammate to associate goals.'
      return
    end

    goal_ids.each do |goal_id|
      goal = Goal.find_by(id: goal_id)
      next unless goal

      ga = associable.goal_associations.build(goal: goal)
      assign_goal_flow_teammate_from_params(ga)
      authorize ga

      if ga.save
        success_count += 1
        schedule_engagement_health_refresh_for_association(ga)
      else
        errors.concat(ga.errors.full_messages)
      end
    end

    owner_teammate = goal_owner_teammate_for_flow || current_teammate
    default_goal_type = 'stepping_stone_activity'
    parse_service = Goals::ParseService.new(bulk_goal_text, default_goal_type)
    parse_result = parse_service.call
    errors.concat(parse_result[:errors]) if parse_result[:errors].any?

    parsed_goals = parse_result[:goals]
    created_goal_map = {}

    parsed_goals.each_with_index do |parsed_goal, index|
      goal = Goal.new(
        title: parsed_goal[:title].to_s.strip,
        description: '',
        goal_type: parsed_goal[:goal_type] || default_goal_type,
        most_likely_target_date: Date.current + 90.days,
        earliest_target_date: nil,
        latest_target_date: nil,
        creator: current_teammate,
        privacy_level: 'only_creator_owner_and_managers'
      )

      goal.owner_type = 'CompanyTeammate'
      goal.owner_id = owner_teammate.id

      if goal.save
        created_goal_map[index] = goal

        if parsed_goal[:parent_index].present?
          parent_goal = created_goal_map[parsed_goal[:parent_index]]
          if parent_goal
            parent_link = GoalLink.new(parent: parent_goal, child: goal)
            parent_link.skip_circular_dependency_check = true
            unless parent_link.save
              errors << "Failed to create parent link for goal '#{goal.title}': #{parent_link.errors.full_messages.join(', ')}"
            end
          else
            errors << "Parent goal not found for '#{goal.title}'"
          end
        else
          ga = associable.goal_associations.build(goal: goal)
          assign_goal_flow_teammate_from_params(ga)
          authorize ga

          if ga.save
            success_count += 1
            schedule_engagement_health_refresh_for_association(ga)
          else
            errors.concat(ga.errors.full_messages)
          end
        end
      else
        errors.concat(goal.errors.full_messages.map { |msg| "#{parsed_goal[:title]}: #{msg}" })
      end
    end

    redirect_url = params[:return_url].presence || default_return_after_goal_association

    if success_count.positive? && errors.empty?
      redirect_to redirect_url,
                  notice: "#{success_count} #{'goal'.pluralize(success_count)} #{success_count == 1 ? 'was' : 'were'} successfully associated."
    elsif success_count.positive? && errors.any?
      redirect_to redirect_url,
                  alert: "Some goals were associated, but there were errors: #{errors.join(', ')}"
    else
      redirect_to associable_goals_manage_path(
        @organization,
        associable,
        **associable_goal_flow_query_params
      ),
                  alert: "Failed to associate goals: #{errors.join(', ')}"
    end
  end

  def destroy
    assign_goal_flow_teammate_from_params(@goal_association)
    authorize @goal_association

    redirect_url = params[:return_url].presence || default_return_after_goal_association

    if @goal_association.destroy
      schedule_engagement_health_refresh_for_association(@goal_association)
      redirect_to redirect_url, notice: 'Goal association was successfully removed.'
    else
      redirect_to redirect_url, alert: 'Failed to remove goal association.'
    end
  end

  private

  # Goals attached to abilities feed the milestones engagement-health category.
  def schedule_engagement_health_refresh_for_association(goal_association)
    return unless goal_association.associable_type == 'Ability'

    EngagementHealth.schedule_refresh_for_goal(goal_association.goal)
  end

  def associable
    @associable
  end

  def set_associable
    @associable = load_associable!
  end

  def load_associable!
    raise NotImplementedError, "#{self.class} must implement #load_associable!"
  end

  def set_goal_association
    @goal_association = associable.goal_associations.find(params[:id])
  end

  def default_return_after_goal_association
    associable_goals_default_show_path(@organization, associable)
  end

  def goal_owner_teammate_for_flow
    tid = params[:for_company_teammate_id].presence
    return if tid.blank?

    ct = CompanyTeammate.find_by(id: tid)
    return unless ct && GoalFlowTeammateScope.teammate_matches_associable?(associable, ct)

    ct
  end
end
