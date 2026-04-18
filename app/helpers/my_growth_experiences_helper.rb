# frozen_string_literal: true

module MyGrowthExperiencesHelper
  SAFE_MY_GROWTH_EXPERIENCES_QUERY_KEYS = %w[show_suggested anchor].freeze

  def my_growth_experiences_return_path_options
    return {} unless respond_to?(:request) && request&.query_parameters

    request.query_parameters.slice(*SAFE_MY_GROWTH_EXPERIENCES_QUERY_KEYS).symbolize_keys
  end

  def my_growth_experiences_return_url(organization, teammate)
    my_growth_experiences_organization_company_teammate_path(
      organization,
      teammate,
      **my_growth_experiences_return_path_options
    )
  end

  def my_growth_observation_new_for_assignment_path(organization, teammate, assignment)
    new_organization_observation_path(
      organization,
      observee_ids: [teammate.id],
      rateable_type: 'Assignment',
      rateable_id: assignment.id,
      return_url: my_growth_experiences_return_url(organization, teammate),
      return_text: 'Grow by experiences'
    )
  end

  def my_growth_goal_flow_allowed_for?(assignment, teammate)
    GoalFlowTeammateScope.teammate_matches_associable?(assignment, teammate) &&
      policy(teammate).audit?
  end

  def my_growth_goal_flow_denied_tooltip
    'You need access as this teammate, their manager, or an employment administrator to set or link goals here.'
  end

  def my_growth_assignment_goal_button_label(casual_name:, assignment:, open_count:)
    if open_count.zero?
      "Set goal for #{casual_name} & #{assignment.title}"
    else
      goals_phrase = "#{open_count} #{open_count == 1 ? 'active goal' : 'active goals'}"
      "Add to the #{goals_phrase} for #{casual_name} & #{assignment.title}"
    end
  end
end
