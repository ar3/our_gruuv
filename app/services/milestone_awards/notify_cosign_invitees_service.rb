# frozen_string_literal: true

module MilestoneAwards
  class NotifyCosignInviteesService
    def self.call(...) = new(...).call

    def initialize(milestone_award:, invitee_teammate_ids: nil)
      @award = milestone_award
      @organization = milestone_award.organization
      @company = @organization.root_company || @organization
      @invitee_teammate_ids = invitee_teammate_ids
    end

    def call
      return Result.err("Slack is not configured") unless @company.slack_configured?

      invites = @award.cosign_invites.open.includes(invitee_teammate: :person)
      if @invitee_teammate_ids.present?
        allowed = @invitee_teammate_ids.map(&:to_i).to_set
        invites = invites.select { |i| allowed.include?(i.invitee_teammate_id) }
      end

      invitees = invites.map(&:invitee_teammate).select { |t| t.slack_user_id.present? }
      return Result.ok(sent: 0) if invitees.empty?

      award_url = Rails.application.routes.url_helpers.organization_teammate_ability_milestone_award_url(
        @organization,
        @award.teammate,
        @award.ability,
        @award
      )
      recipient_name = @award.teammate.person.display_name
      ability_name = @award.ability.display_name
      level = @award.official_milestone_level
      awarder_name = @award.certifying_teammate.person.display_name
      awarder_slack = @award.certifying_teammate.slack_user_id

      slack_service = SlackService.new(@company)
      sent = 0
      errors = []

      invitees.each do |invitee|
        channel_id = resolve_channel(slack_service, invitee, awarder_slack)
        text = "*Milestone co-sign request*\n\n#{awarder_name} asked you to co-sign " \
               "#{ability_name} Milestone #{level} for #{recipient_name}. " \
               "Please respond Yes or No.\n\n" \
               "<#{award_url}|Review and respond>"

        blocks = [{ type: "section", text: { type: "mrkdwn", text: text } }]
        notification = @award.notifications.create!(
          notification_type: "milestone_cosign_request",
          status: "preparing_to_send",
          metadata: { channel: channel_id, teammate_id: invitee.id },
          rich_message: blocks,
          fallback_text: text
        )

        result = slack_service.post_message(notification.id)
        if result[:success]
          sent += 1
        else
          errors << "#{invitee.person.display_name}: #{result[:error]}"
        end
      end

      errors.any? ? Result.err(errors.join("; ")) : Result.ok(sent: sent)
    rescue StandardError => e
      Result.err(e.message)
    end

    private

    def resolve_channel(slack_service, invitee, awarder_slack_user_id)
      user_ids = [invitee.slack_user_id, awarder_slack_user_id].compact.uniq
      return invitee.slack_user_id if user_ids.size < 2

      result = slack_service.open_or_create_group_dm(user_ids: user_ids)
      result[:success] ? result[:channel_id] : invitee.slack_user_id
    end
  end
end
