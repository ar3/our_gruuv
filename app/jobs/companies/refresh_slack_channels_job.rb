class Companies::RefreshSlackChannelsJob < ApplicationJob
  queue_as :default

  def perform(company_id)
    Rails.logger.info "RefreshSlackChannelsJob: Starting for company #{company_id}"
    company = Company.find(company_id)
    
    Rails.logger.info "RefreshSlackChannelsJob: Found company #{company.id} (#{company.name})"
    Rails.logger.info "RefreshSlackChannelsJob: Slack configured? #{company.slack_configured?}"
    
    return false unless company.slack_configured?
    
    Rails.logger.info "RefreshSlackChannelsJob: Creating SlackChannelsService"
    service = SlackChannelsService.new(company)
    
    Rails.logger.info "RefreshSlackChannelsJob: Calling refresh_channels"
    result = service.refresh_channels
    Rails.logger.info "RefreshSlackChannelsJob: refresh_channels returned #{result}"
    
    result
  end
end 