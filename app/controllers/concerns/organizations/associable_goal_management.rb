# frozen_string_literal: true

module Organizations
  module AssociableGoalManagement
    extend ActiveSupport::Concern

    included do
      include LoadAssociableGoalsDisplay
      include Organizations::AssociableGoalFlowParams
    end

    def choose_manage_goals
      authorize_goal_flow_for_associable_goals!
      @associable = associable_for_goal_management
      assign_goal_flow_overlay_request_context!
      @return_url = params[:return_url].presence || default_associable_goals_return_url
      @return_text = params[:return_text].presence || default_associable_goals_return_text
      render 'organizations/shared/associable_goals/choose_manage_goals', layout: 'overlay'
    end

    def manage_goals
      authorize_goal_flow_for_associable_goals!
      @associable = associable_for_goal_management
      assign_goal_flow_overlay_request_context!
      @return_url = params[:return_url].presence || default_associable_goals_return_url
      @return_text = params[:return_text].presence || default_associable_goals_return_text
      render 'organizations/shared/associable_goals/manage_goals', layout: 'overlay'
    end

    def associate_existing_goals
      authorize_goal_flow_for_associable_goals!
      @associable = associable_for_goal_management
      assign_goal_flow_overlay_request_context!

      if request.get?
        candidate_goals = associable_goal_candidate_goals
        associated_goal_ids = @associable.goal_ids.to_set
        @available_goals_with_status = candidate_goals.map do |g|
          { goal: g, already_associated: associated_goal_ids.include?(g.id) }
        end
        @return_url = params[:return_url].presence || default_associable_goals_return_url
        @return_text = params[:return_text].presence || default_associable_goals_return_text
        render 'organizations/shared/associable_goals/associate_existing_goals', layout: 'overlay'
        return
      end

      goal_ids = Array(params[:goal_ids]).reject(&:blank?)
      return_url = params[:return_url].presence || default_associable_goals_return_url

      if goal_ids.empty?
        redirect_to associable_goals_associate_existing_path(
          @organization,
          @associable,
          **associable_goal_flow_query_params.merge(return_url: return_url, return_text: params[:return_text]).compact
        ),
                    alert: 'Please select at least one goal.'
        return
      end

      success_count = 0
      errors = []

      goal_ids.each do |goal_id|
        goal = associable_goal_candidate_goals.find { |g| g.id == goal_id.to_i }
        next unless goal

        ga = @associable.goal_associations.build(goal: goal)
        assign_goal_flow_teammate_from_params(ga)
        authorize ga, :create?
        if ga.save
          success_count += 1
        else
          errors.concat(ga.errors.full_messages)
        end
      end

      if success_count.positive? && errors.empty?
        redirect_to return_url,
                    notice: "#{success_count} #{'goal'.pluralize(success_count)} #{success_count == 1 ? 'was' : 'were'} successfully associated."
      elsif success_count.positive? && errors.any?
        redirect_to return_url,
                    alert: "Some goals were associated, but there were errors: #{errors.join(', ')}"
      else
        redirect_to associable_goals_associate_existing_path(
          @organization,
          @associable,
          **associable_goal_flow_query_params.merge(return_url: return_url, return_text: params[:return_text]).compact
        ),
                    alert: "Failed to associate goals: #{errors.join(', ')}"
      end
    end

    private

    def assign_goal_flow_overlay_request_context!
      @for_company_teammate_id = params[:for_company_teammate_id].presence
      @goal_flow_for_company_teammate =
        if @for_company_teammate_id.present?
          CompanyTeammate.includes(:person).find_by(id: @for_company_teammate_id)
        end
    end

    def authorize_goal_flow_for_associable_goals!
      associable = associable_for_goal_management
      if params[:for_company_teammate_id].present?
        subject_teammate = CompanyTeammate.find_by(id: params[:for_company_teammate_id])
        unless subject_teammate && GoalFlowTeammateScope.teammate_matches_associable?(associable, subject_teammate)
          raise Pundit::NotAuthorizedError
        end

        authorize subject_teammate, :audit?, policy_class: CompanyTeammatePolicy
      else
        authorize associable, :update?
      end
    end

    def associable_for_goal_management
      raise NotImplementedError, "#{self.class} must implement #associable_for_goal_management"
    end

    def default_associable_goals_return_url
      associable_goals_default_show_path(@organization, associable_for_goal_management)
    end

    def default_associable_goals_return_text
      associable_display_title(associable_for_goal_management)
    end

    def associable_goal_candidate_goals
      goals = Goals::AssociableGoalCandidatesQuery.new(
        associable: @associable,
        goals_scope: policy_scope(Goal)
      ).call.to_a
      goals.select! { |goal| goal.can_be_viewed_by?(current_person) }

      if params[:for_company_teammate_id].present?
        subject_teammate = CompanyTeammate.find_by(id: params[:for_company_teammate_id])
        if subject_teammate
          goals.select! do |goal|
            goal.owner_type == "CompanyTeammate" && goal.owner_id == subject_teammate.id
          end
        end
      end

      goals
    end
  end
end
