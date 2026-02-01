module Slack
  class ProcessHuddleCommandService
    def self.call(organization:, user_id:, channel_id:, command_info: {})
      new(organization: organization, user_id: user_id, channel_id: channel_id, command_info: command_info).call
    end

    def initialize(organization:, user_id:, channel_id:, command_info: {})
      @organization = organization
      @user_id = user_id
      @channel_id = channel_id
      @command_info = command_info
    end

    def call
      # 1. Find the Slack channel by channel_id
      slack_channel = @organization.third_party_objects.slack_channels.find_by(third_party_id: @channel_id)
      unless slack_channel
        return Result.err("No huddle configured for this channel.")
      end

      # 2. Find the team that has this channel as their huddle_channel
      team = Team.joins(:third_party_object_associations)
                 .where(company: @organization)
                 .where(third_party_object_associations: {
                   association_type: 'huddle_channel',
                   third_party_object_id: slack_channel.id
                 })
                 .first

      unless team
        return Result.err("No huddle configured for this channel.")
      end

      # 3. Check if there's already an active huddle for this team
      existing_huddle = Huddle.where(team: team)
                             .where('expires_at > ?', Time.current)
                             .order(started_at: :desc)
                             .first

      if existing_huddle
        url_options = Rails.application.routes.default_url_options || {}
        huddle_url = Rails.application.routes.url_helpers.huddle_url(existing_huddle, url_options)
        return Result.ok("Huddle is already started with the link: #{huddle_url}")
      end

      # 4. Create a new huddle
      huddle = Huddle.new(
        team: team,
        started_at: Time.current,
        expires_at: 24.hours.from_now
      )

      unless huddle.save
        error_message = "Failed to create huddle: #{huddle.errors.full_messages.join(', ')}"
        return Result.err(error_message)
      end

      # 5. Post announcements to Slack
      Huddles::PostAnnouncementJob.perform_and_get_result(huddle.id)
      Huddles::PostSummaryJob.perform_and_get_result(huddle.id)

      # 6. Run weekly summary job if applicable
      if huddle.company&.root_company
        Companies::WeeklyHuddlesReviewNotificationJob.perform_later(huddle.company.root_company.id)
      end

      url_options = Rails.application.routes.default_url_options || {}
      huddle_url = Rails.application.routes.url_helpers.huddle_url(huddle, url_options)
      Result.ok("Huddle started successfully! View it here: #{huddle_url}")
    rescue => e
      error_message = "Unexpected error processing huddle command: #{e.message}"
      Rails.logger.error "Slack::ProcessHuddleCommandService error: #{error_message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      Result.err(error_message)
    end
  end
end
