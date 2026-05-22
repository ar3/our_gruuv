# frozen_string_literal: true

module Digest
  module SlackWeeklyDigestChannel
    DIGEST_BOT_USERNAME = 'ourgruuvbot'

    private

    def open_weekly_digest_slack_channel(teammate)
      return nil unless teammate&.organization

      manager_teammate = teammate.active_employment_tenure&.manager_teammate
      employee_prefs = UserPreference.for_person(teammate.person)
      employee_slack_enabled = employee_prefs.effective_digest_slack(nil) == 'on'
      manager_slack_enabled =
        manager_teammate.present? &&
        UserPreference.for_person(manager_teammate.person).effective_digest_slack(nil) == 'on'
      return nil unless employee_slack_enabled || manager_slack_enabled

      user_ids = []
      user_ids << teammate.slack_user_id if teammate.has_slack_identity? && teammate.slack_user_id.present?
      if manager_teammate&.has_slack_identity? && manager_teammate.slack_user_id.present?
        user_ids << manager_teammate.slack_user_id
      end
      user_ids.uniq!
      return nil if user_ids.empty?

      organization = teammate.organization
      return nil unless organization.calculated_slack_config&.configured?

      slack_service = SlackService.new(organization)
      dm =
        if user_ids.one?
          slack_service.open_dm(user_id: user_ids.first)
        else
          slack_service.open_or_create_group_dm(user_ids: user_ids)
        end
      return nil unless dm[:success] && dm[:channel_id].present?

      {
        slack_service: slack_service,
        manager_teammate: manager_teammate,
        digest_metadata: { channel: dm[:channel_id], username: DIGEST_BOT_USERNAME }
      }
    end
  end
end
