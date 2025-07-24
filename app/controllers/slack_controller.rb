class SlackController < ApplicationController
  def index
    # Show the top-level Slack dashboard
    render :index
  end

  def show
    # Similar to index - redirect to organization-specific Slack
    if current_person&.current_organization
      redirect_to organization_slack_path(current_person.current_organization)
    else
      redirect_to organizations_path, alert: 'Please select an organization to manage Slack integration'
    end
  end

  def test_connection
    # This would test the current organization's Slack connection
    if current_person&.current_organization&.slack_configuration
      result = SlackService.new(current_person.current_organization).test_connection
      render json: result
    else
      render json: { error: 'No Slack configuration found' }, status: :not_found
    end
  end

  def list_channels
    if current_person&.current_organization&.slack_configuration
      channels = SlackService.new(current_person.current_organization).list_channels
      render json: channels
    else
      render json: { error: 'No Slack configuration found' }, status: :not_found
    end
  end

  def post_test_message
    if current_person&.current_organization&.slack_configuration
      result = SlackService.new(current_person.current_organization).post_test_message
      render json: result
    else
      render json: { error: 'No Slack configuration found' }, status: :not_found
    end
  end

  def configuration_status
    if current_person&.current_organization&.slack_configuration
      render json: { configured: true, organization: current_person.current_organization.name }
    else
      render json: { configured: false }
    end
  end
end 