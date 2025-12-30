module Slack
  class PostGoalCheckInConfirmationJob < ApplicationJob
    queue_as :default
    
    def perform(organization_id, user_id, goal_id)
      organization = Organization.find_by(id: organization_id)
      return unless organization
      
      goal = Goal.find_by(id: goal_id)
      return unless goal
      
      # Build goal URL
      url_options = Rails.application.routes.default_url_options || {}
      goal_url = Rails.application.routes.url_helpers.organization_goal_url(
        organization,
        goal,
        url_options
      )
      
      # Post confirmation message
      slack_service = SlackService.new(organization)
      dm_result = slack_service.post_dm(
        user_id: user_id,
        text: "✅ Check-in saved for goal: #{goal.title}\nView it here: #{goal_url}"
      )
      
      unless dm_result[:success]
        Rails.logger.error "Slack::PostGoalCheckInConfirmationJob: Failed to post DM - #{dm_result[:error]}"
      end
    rescue => e
      Rails.logger.error "Slack::PostGoalCheckInConfirmationJob: Error - #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
    end
  end
end

