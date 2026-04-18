# frozen_string_literal: true

module MyGrowthExperiencesHelper
  include AssociableGoalsHelper

  MY_GROWTH_SHARED_QUERY_KEYS = %w[show_suggested anchor].freeze

  def my_growth_shared_return_path_options
    return {} unless respond_to?(:request) && request&.query_parameters

    request.query_parameters.slice(*MY_GROWTH_SHARED_QUERY_KEYS).symbolize_keys
  end

  def my_growth_experiences_return_path_options
    my_growth_shared_return_path_options
  end

  def my_growth_experiences_return_url(organization, teammate)
    my_growth_experiences_organization_company_teammate_path(
      organization,
      teammate,
      **my_growth_shared_return_path_options
    )
  end

  def my_growth_abilities_return_url(organization, teammate)
    my_growth_abilities_organization_company_teammate_path(
      organization,
      teammate,
      **my_growth_shared_return_path_options
    )
  end

  def my_growth_complete_picture_return_url(organization, teammate)
    complete_picture_organization_company_teammate_path(
      organization,
      teammate,
      **my_growth_shared_return_path_options
    )
  end

  def my_growth_observation_new_for_associable_path(organization, teammate, associable, return_url:, return_text:)
    new_organization_observation_path(
      organization,
      observee_ids: [teammate.id],
      rateable_type: associable.class.name,
      rateable_id: associable.id,
      return_url: return_url,
      return_text: return_text
    )
  end

  def my_growth_goal_flow_allowed_for_associable?(associable, teammate)
    GoalFlowTeammateScope.teammate_matches_associable?(associable, teammate) &&
      policy(teammate).audit?
  end

  def my_growth_goal_flow_denied_tooltip
    'You need access as this teammate, their manager, or an employment administrator to set or link goals here.'
  end

  def my_growth_catalog_goal_button_label(casual_name:, associable:, open_count:)
    title = associable_display_title(associable)
    if open_count.zero?
      "Set goal for #{casual_name} & #{title}"
    else
      goals_phrase = "#{open_count} #{open_count == 1 ? 'active goal' : 'active goals'}"
      "Add to the #{goals_phrase} for #{casual_name} & #{title}"
    end
  end
end
