module Slack
  class ProcessGoalCheckCommandService
    def self.call(organization:, user_id:, trigger_id:, command_info: {})
      new(organization: organization, user_id: user_id, trigger_id: trigger_id, command_info: command_info).call
    end
    
    def initialize(organization:, user_id:, trigger_id:, command_info: {})
      @organization = organization
      @user_id = user_id
      @trigger_id = trigger_id
      @command_info = command_info
      @slack_service = SlackService.new(@organization)
    end
    
    def call
      # 1. Resolve the teammate from Slack user_id
      teammate = TeammateIdentity.find_teammate_by_slack_id(@user_id, @organization)
      unless teammate
        return Result.err("You are not found in OurGruuv. Please ensure your Slack account is linked to your OurGruuv profile.")
      end
      
      # 2. Find goals that the teammate can check in on
      goals = Goal.for_teammate(teammate).active.check_in_eligible.order(:most_likely_target_date)
      
      if goals.empty?
        url_options = Rails.application.routes.default_url_options || {}
        goals_url = Rails.application.routes.url_helpers.organization_goals_url(@organization, url_options)
        return Result.err("You don't have any goals available for check-in. Create a goal first in OurGruuv: #{goals_url}")
      end
      
      # 3. Build goal options for the modal dropdown
      # Slack static_select has a 75 character limit for option text
      goal_options = goals.map do |goal|
        {
          text: {
            type: 'plain_text',
            text: goal.title.length > 75 ? "#{goal.title[0..71]}..." : goal.title
          },
          value: goal.id.to_s
        }
      end
      
      # 4. Build private metadata
      private_metadata = {
        user_id: @user_id,
        teammate_id: teammate.id,
        organization_id: @organization.id
      }.to_json
      
      # 5. Open the goal check-in modal
      view = {
        type: 'modal',
        callback_id: 'goal_check_in',
        title: {
          type: 'plain_text',
          text: 'Goal Check-In'
        },
        submit: {
          type: 'plain_text',
          text: 'Submit Check-In'
        },
        close: {
          type: 'plain_text',
          text: 'Cancel'
        },
        private_metadata: private_metadata,
        blocks: [
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: "Select a goal to check in on for this week (#{Date.current.beginning_of_week(:monday).strftime('%b %d')} - #{Date.current.end_of_week(:sunday).strftime('%b %d, %Y')}):"
            }
          },
          {
            type: 'input',
            block_id: 'goal_selection',
            element: {
              type: 'static_select',
              action_id: 'goal_selection',
              placeholder: {
                type: 'plain_text',
                text: 'Select a goal...'
              },
              options: goal_options
            },
            label: {
              type: 'plain_text',
              text: 'Goal'
            }
          },
          {
            type: 'input',
            block_id: 'confidence_percentage',
            element: {
              type: 'plain_text_input',
              action_id: 'confidence_percentage',
              placeholder: {
                type: 'plain_text',
                text: '0-100'
              },
              initial_value: ''
            },
            label: {
              type: 'plain_text',
              text: 'Confidence Percentage (0-100)'
            },
            hint: {
              type: 'plain_text',
              text: 'Optional: Your confidence level for achieving this goal'
            },
            optional: true
          },
          {
            type: 'input',
            block_id: 'confidence_reason',
            element: {
              type: 'plain_text_input',
              action_id: 'confidence_reason',
              multiline: true,
              placeholder: {
                type: 'plain_text',
                text: 'Why this confidence level? What progress have you made?'
              },
              initial_value: ''
            },
            label: {
              type: 'plain_text',
              text: 'Confidence Reason'
            },
            hint: {
              type: 'plain_text',
              text: 'Optional: Explain your confidence level or progress'
            },
            optional: true
          }
        ]
      }
      
      result = @slack_service.open_modal(@trigger_id, view)
      
      if result[:success]
        Result.ok("Opening goal check-in form...")
      else
        Result.err("Failed to open check-in form: #{result[:error]}")
      end
    rescue => e
      error_message = "Unexpected error processing goal-check command: #{e.message}"
      Rails.logger.error "Slack::ProcessGoalCheckCommandService error: #{error_message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      Result.err(error_message)
    end
  end
end

