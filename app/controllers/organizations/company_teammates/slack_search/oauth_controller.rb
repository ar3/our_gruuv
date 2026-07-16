# frozen_string_literal: true

class Organizations::CompanyTeammates::SlackSearch::OauthController < ApplicationController
  include Organizations::ResolvesMeTeammateParam

  before_action :require_authentication
  before_action :set_organization, except: [:callback]
  before_action :set_organization_and_teammate_from_state, only: [:callback]
  before_action :set_teammate, only: [:authorize, :disconnect]
  before_action :ensure_own_teammate!, only: [:authorize, :disconnect]

  PROVIDER = "slack_search"
  DEFAULT_USER_SCOPE = "search:read"

  def authorize
    client_id = ENV["SLACK_CLIENT_ID"]
    redirect_uri = slack_search_oauth_callback_url
    user_scope = ENV.fetch("SLACK_SEARCH_USER_SCOPE", DEFAULT_USER_SCOPE)
    source = params[:source].presence || "identities"
    source = "sourceFromSlack" if source == "source_from_slack"
    return_url = params[:return_to] || params[:return_url]
    return_url_encoded = return_url.present? ? Base64.urlsafe_encode64(return_url) : ""
    state = "#{@organization.id}_#{@teammate.id}_#{source}_#{return_url_encoded}"

    oauth_url =
      "https://slack.com/oauth/v2/authorize?" \
      "client_id=#{CGI.escape(client_id.to_s)}" \
      "&user_scope=#{CGI.escape(user_scope)}" \
      "&redirect_uri=#{CGI.escape(redirect_uri)}" \
      "&state=#{CGI.escape(state)}"

    redirect_to oauth_url, allow_other_host: true
  end

  def callback
    code = params[:code]
    if code.blank?
      redirect_to oauth_fallback_path, alert: "Slack search connection was cancelled or failed."
      return
    end

    client_id = ENV["SLACK_CLIENT_ID"]
    client_secret = ENV["SLACK_CLIENT_SECRET"]
    redirect_uri = slack_search_oauth_callback_url

    response = HTTP.post("https://slack.com/api/oauth.v2.access", form: {
      client_id: client_id,
      client_secret: client_secret,
      code: code,
      redirect_uri: redirect_uri
    })
    data = JSON.parse(response.body.to_s)

    unless data["ok"]
      redirect_to oauth_fallback_path, alert: "Failed to connect Slack search: #{data['error'] || 'Unknown error'}"
      return
    end

    authed_user = data["authed_user"] || {}
    access_token = authed_user["access_token"]
    slack_user_id = authed_user["id"]

    if access_token.blank? || slack_user_id.blank?
      redirect_to oauth_fallback_path, alert: "Failed to connect Slack search: missing user token from Slack."
      return
    end

    profile = fetch_slack_user_profile(access_token, slack_user_id)

    identity = @teammate.teammate_identities.find_or_initialize_by(provider: PROVIDER)
    identity.uid = slack_user_id
    identity.email = profile[:email]
    identity.name = profile[:name]
    identity.profile_image_url = profile[:profile_image_url]
    identity.raw_data = {
      "info" => profile[:raw_info],
      "credentials" => {
        "token" => access_token,
        "scope" => authed_user["scope"],
        "token_type" => authed_user["token_type"] || "user",
        "team_id" => data.dig("team", "id")
      },
      "extra" => data
    }

    if identity.save
      redirect_to oauth_fallback_path, notice: "Slack (search) connected successfully. You can search Slack as yourself."
    else
      redirect_to oauth_fallback_path,
                  alert: "Failed to save Slack search identity: #{identity.errors.full_messages.join(', ')}"
    end
  rescue StandardError => e
    Rails.logger.error "Slack search OAuth error: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    redirect_to oauth_fallback_path, alert: "Failed to connect Slack search: #{e.message}"
  end

  def disconnect
    identity = @teammate.slack_search_identity
    if identity&.destroy
      redirect_to disconnect_fallback_path, notice: "Slack (search) disconnected successfully."
    elsif identity.nil?
      redirect_to disconnect_fallback_path, alert: "No Slack (search) account connected to disconnect."
    else
      redirect_to disconnect_fallback_path, alert: "Failed to disconnect Slack (search). Please try again."
    end
  end

  private

  def organization
    @organization
  end

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_teammate
    @teammate = find_organization_teammate!(params[:company_teammate_id])
  end

  def set_organization_and_teammate_from_state
    state = params[:state]
    if state.blank?
      redirect_to root_path, alert: "Invalid OAuth callback: missing state parameter"
      return
    end

    parts = state.split("_", 4)
    @organization = Organization.find(parts[0])
    @teammate = CompanyTeammate.find(parts[1])
    @oauth_source = parts[2].presence || "identities"
    @return_url =
      if parts[3].present?
        Base64.urlsafe_decode64(parts[3])
      end
  rescue ActiveRecord::RecordNotFound, ArgumentError
    redirect_to root_path, alert: "Invalid OAuth callback: organization or teammate not found"
  end

  def ensure_own_teammate!
    return if @teammate.person_id == current_person.id

    redirect_to organization_company_teammate_path(@organization, @teammate),
                alert: "You can only connect Slack (search) for yourself."
  end

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to connect Slack search."
  end

  def oauth_fallback_path
    return @return_url if @return_url.present?

    if @oauth_source == "sourceFromSlack"
      ogos_source_from_slack_organization_company_teammate_path(@organization, @teammate)
    else
      organization_company_teammate_path(@organization, @teammate)
    end
  end

  def disconnect_fallback_path
    return_to = params[:return_to].presence
    return return_to if return_to.present?

    organization_company_teammate_path(@organization, @teammate)
  end

  def fetch_slack_user_profile(access_token, slack_user_id)
    auth_response = HTTP.get(
      "https://slack.com/api/auth.test",
      headers: { "Authorization" => "Bearer #{access_token}" }
    )
    auth_data = JSON.parse(auth_response.body.to_s)

    name = auth_data["user"]
    email = nil
    profile_image_url = nil
    raw_info = auth_data

    user_response = HTTP.get(
      "https://slack.com/api/users.info",
      params: { user: slack_user_id },
      headers: { "Authorization" => "Bearer #{access_token}" }
    )
    user_data = JSON.parse(user_response.body.to_s)
    if user_data["ok"]
      user = user_data["user"] || {}
      profile = user["profile"] || {}
      name = user["real_name"].presence || profile["real_name"].presence || name
      email = profile["email"]
      profile_image_url = profile["image_72"] || profile["image_48"] || profile["image_32"]
      raw_info = user_data
    end

    {
      name: name,
      email: email,
      profile_image_url: profile_image_url,
      raw_info: raw_info
    }
  end
end
