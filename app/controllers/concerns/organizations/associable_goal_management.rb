# frozen_string_literal: true

module Organizations
  module AssociableGoalManagement
    extend ActiveSupport::Concern

    included do
      include LoadAssociableGoalsDisplay
    end

    def choose_manage_goals
      authorize associable_for_goal_management, :update?
      @associable = associable_for_goal_management
      @return_url = params[:return_url].presence || default_associable_goals_return_url
      @return_text = params[:return_text].presence || default_associable_goals_return_text
      render 'organizations/shared/associable_goals/choose_manage_goals', layout: 'overlay'
    end

    def manage_goals
      authorize associable_for_goal_management, :update?
      @associable = associable_for_goal_management
      @return_url = params[:return_url].presence || default_associable_goals_return_url
      @return_text = params[:return_text].presence || default_associable_goals_return_text
      render 'organizations/shared/associable_goals/manage_goals', layout: 'overlay'
    end

    def associate_existing_goals
      authorize associable_for_goal_management, :update?
      @associable = associable_for_goal_management

      if request.get?
        candidate_goals = Goals::AssociableGoalCandidatesQuery.new(
          associable: @associable,
          goals_scope: policy_scope(Goal)
        ).call
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
          return_url: return_url,
          return_text: params[:return_text]
        ),
                    alert: 'Please select at least one goal.'
        return
      end

      success_count = 0
      errors = []

      goal_ids.each do |goal_id|
        goal = Goal.find_by(id: goal_id)
        next unless goal

        ga = @associable.goal_associations.build(goal: goal)
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
          return_url: return_url,
          return_text: params[:return_text]
        ),
                    alert: "Failed to associate goals: #{errors.join(', ')}"
      end
    end

    private

    def associable_for_goal_management
      raise NotImplementedError, "#{self.class} must implement #associable_for_goal_management"
    end

    def default_associable_goals_return_url
      associable_goals_default_show_path(@organization, associable_for_goal_management)
    end

    def default_associable_goals_return_text
      associable_display_title(associable_for_goal_management)
    end
  end
end
