# frozen_string_literal: true

module CheckIns
  # Slack MPIM (viewer + other party) when the viewer's side is clear on unhealthy
  # Up Next check-ins and the other person still needs to complete theirs.
  class UpNextWaitingNudgeService
    include Rails.application.routes.url_helpers

    NOTIFICATION_TYPE = "check_in_up_next_waiting_nudge"

    def self.call(organization:, employee_teammate:, viewing_person:, viewing_teammate:, waiting_count:)
      new(
        organization: organization,
        employee_teammate: employee_teammate,
        viewing_person: viewing_person,
        viewing_teammate: viewing_teammate,
        waiting_count: waiting_count
      ).call
    end

    def self.message_body(waiting_count:, up_next_url: nil)
      count = waiting_count.to_i
      item_word = count == 1 ? "check-in" : "check-ins"
      body = "Tag you're it... let's make sure we are clear on where we stand by completing " \
             "the #{count} #{item_word}... when should we schedule our review of these together?"
      return body if up_next_url.blank?

      "#{body}\n\nUp Next: #{up_next_url}"
    end

    def self.last_delivered_between(employee_teammate:, viewer_teammate:, other_teammate:)
      return nil if employee_teammate.blank? || viewer_teammate.blank? || other_teammate.blank?

      pair = [viewer_teammate.id, other_teammate.id].map(&:to_i).sort
      employee_teammate.notifications
        .where(notification_type: NOTIFICATION_TYPE)
        .successful
        .where.not(message_id: nil)
        .order(created_at: :desc)
        .detect do |n|
          stored = Array(n.metadata&.dig("pair_company_teammate_ids")).map(&:to_i).sort
          stored == pair
        end
    end

    def initialize(organization:, employee_teammate:, viewing_person:, viewing_teammate:, waiting_count:)
      @organization = organization
      @employee_teammate = employee_teammate
      @viewing_person = viewing_person
      @viewing_teammate = viewing_teammate
      @waiting_count = waiting_count.to_i
    end

    def call
      return Result.err("Nothing waiting on the other person right now.") if @waiting_count <= 0
      return Result.err("You must be signed in as a teammate to send this nudge.") if @viewing_teammate.blank?

      other = other_party_teammate
      return Result.err("Could not find the other person for this nudge.") if other.blank?
      return Result.err("Viewer and other party must be two different people.") if other.id == @viewing_teammate.id

      viewer_slack = @viewing_teammate.slack_user_id
      other_slack = other.slack_user_id
      if viewer_slack.blank? || other_slack.blank?
        return Result.err("Both you and the other person must have Slack connected to send a nudge.")
      end

      slack_service = SlackService.new(@organization)
      dm_result = slack_service.open_or_create_group_dm(user_ids: [viewer_slack, other_slack])
      return Result.err(dm_result[:error].presence || "Could not open Slack group DM.") unless dm_result[:success]

      channel_id = dm_result[:channel_id]
      up_next_url = up_next_organization_company_teammate_check_ins_url(
        @organization,
        @employee_teammate,
        mail_url_options
      )
      fallback_text = self.class.message_body(waiting_count: @waiting_count, up_next_url: up_next_url)
      blocks = [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: fallback_text
          }
        }
      ]

      notification = @employee_teammate.notifications.create!(
        notification_type: NOTIFICATION_TYPE,
        status: "preparing_to_send",
        metadata: {
          "channel" => channel_id,
          "nudger_company_teammate_id" => @viewing_teammate.id,
          "other_party_company_teammate_id" => other.id,
          "pair_company_teammate_ids" => [@viewing_teammate.id, other.id].sort,
          "waiting_count" => @waiting_count
        },
        rich_message: blocks,
        fallback_text: fallback_text
      )

      post_result = slack_service.post_message(notification.id)
      if post_result[:success]
        Result.ok(notification: notification.reload)
      else
        Result.err(post_result[:error].presence || "Slack failed to post the nudge.")
      end
    rescue Slack::Web::Api::Errors::SlackError => e
      Result.err("Slack error: #{e.message}")
    rescue StandardError => e
      Result.err(e.message)
    end

    private

    def other_party_teammate
      if @viewing_person&.id == @employee_teammate.person_id
        @employee_teammate.employment_tenures.active.first&.manager_teammate
      else
        @employee_teammate
      end
    end

    def mail_url_options
      base = Rails.application.config.action_mailer.default_url_options.presence ||
             Rails.application.routes.default_url_options || {}
      base = base.symbolize_keys
      base.reverse_merge(host: "localhost", protocol: "http")
    end
  end
end
