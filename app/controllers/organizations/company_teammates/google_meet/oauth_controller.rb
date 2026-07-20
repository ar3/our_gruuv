# frozen_string_literal: true

class Organizations::CompanyTeammates::GoogleMeet::OauthController < ApplicationController
  include Organizations::ResolvesMeTeammateParam

  before_action :require_authentication
  before_action :set_organization, except: [:callback]
  before_action :set_organization_and_teammate_from_state, only: [:callback]
  before_action :set_teammate, only: %i[authorize disconnect]
  before_action :ensure_own_teammate!, only: %i[authorize disconnect]

  PROVIDER = "google_meet"
  DEFAULT_SCOPES = [
    "https://www.googleapis.com/auth/meetings.space.readonly",
    "https://www.googleapis.com/auth/drive.meet.readonly",
    "openid",
    "email",
    "profile"
  ].freeze

  def authorize
    client_id = ENV["GOOGLE_CLIENT_ID"]
    redirect_uri = google_meet_oauth_callback_url
    scope = ENV.fetch("GOOGLE_MEET_OAUTH_SCOPE", DEFAULT_SCOPES.join(" "))
    source = params[:source].presence || "identities"
    source = "consultOg" if source.in?(%w[consult_og consultOg])
    return_url = params[:return_to] || params[:return_url]
    return_url_encoded = return_url.present? ? Base64.urlsafe_encode64(return_url) : ""
    state = "#{@organization.id}_#{@teammate.id}_#{source}_#{return_url_encoded}"

    oauth_url =
      "https://accounts.google.com/o/oauth2/v2/auth?" \
      "client_id=#{CGI.escape(client_id.to_s)}" \
      "&redirect_uri=#{CGI.escape(redirect_uri)}" \
      "&response_type=code" \
      "&scope=#{CGI.escape(scope)}" \
      "&access_type=offline" \
      "&prompt=consent" \
      "&include_granted_scopes=true" \
      "&state=#{CGI.escape(state)}"

    redirect_to oauth_url, allow_other_host: true
  end

  def callback
    code = params[:code]
    if code.blank?
      redirect_to oauth_fallback_path, alert: "Google Meet connection was cancelled or failed."
      return
    end

    client_id = ENV["GOOGLE_CLIENT_ID"]
    client_secret = ENV["GOOGLE_CLIENT_SECRET"]
    redirect_uri = google_meet_oauth_callback_url

    response = HTTP.post("https://oauth2.googleapis.com/token", form: {
      grant_type: "authorization_code",
      client_id: client_id,
      client_secret: client_secret,
      code: code,
      redirect_uri: redirect_uri
    })
    data = JSON.parse(response.body.to_s)

    unless data["access_token"]
      redirect_to oauth_fallback_path,
                  alert: "Failed to connect Google Meet: #{data['error_description'] || data['error'] || 'Unknown error'}"
      return
    end

    profile = fetch_google_user_profile(data["access_token"])
    uid = profile[:uid]
    if uid.blank?
      redirect_to oauth_fallback_path, alert: "Failed to connect Google Meet: missing user id from Google."
      return
    end

    identity = @teammate.teammate_identities.find_or_initialize_by(provider: PROVIDER)
    identity.uid = uid
    identity.email = profile[:email]
    identity.name = profile[:name]
    identity.profile_image_url = profile[:profile_image_url]
    identity.raw_data = {
      "info" => profile[:raw_info],
      "credentials" => {
        "token" => data["access_token"],
        "refresh_token" => data["refresh_token"].presence || identity.raw_credentials["refresh_token"],
        "expires_at" => data["expires_in"] ? (Time.current + data["expires_in"].to_i.seconds).iso8601 : nil,
        "scope" => data["scope"],
        "token_type" => data["token_type"] || "Bearer"
      },
      "extra" => data.except("access_token", "refresh_token")
    }

    if identity.save
      redirect_to oauth_fallback_path,
                  notice: "Google Meet (transcripts) connected. You can import transcripts from meetings you organized."
    else
      redirect_to oauth_fallback_path,
                  alert: "Failed to save Google Meet identity: #{identity.errors.full_messages.join(', ')}"
    end
  rescue StandardError => e
    Rails.logger.error "Google Meet OAuth error: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    redirect_to oauth_fallback_path, alert: "Failed to connect Google Meet: #{e.message}"
  end

  def disconnect
    identity = @teammate.google_meet_identity
    if identity&.destroy
      redirect_to disconnect_fallback_path, notice: "Google Meet (transcripts) disconnected successfully."
    elsif identity.nil?
      redirect_to disconnect_fallback_path, alert: "No Google Meet (transcripts) account connected to disconnect."
    else
      redirect_to disconnect_fallback_path, alert: "Failed to disconnect Google Meet (transcripts). Please try again."
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
                alert: "You can only connect Google Meet (transcripts) for yourself."
  end

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to connect Google Meet."
  end

  def oauth_fallback_path
    return @return_url if @return_url.present?

    if @oauth_source == "consultOg"
      new_organization_possible_observation_consult_path(@organization)
    else
      organization_company_teammate_path(@organization, @teammate)
    end
  end

  def disconnect_fallback_path
    return_to = params[:return_to].presence
    return return_to if return_to.present?

    organization_company_teammate_path(@organization, @teammate)
  end

  def fetch_google_user_profile(access_token)
    response = HTTP.auth("Bearer #{access_token}")
                   .get("https://www.googleapis.com/oauth2/v3/userinfo")
    data = JSON.parse(response.body.to_s)

    {
      uid: data["sub"],
      name: data["name"],
      email: data["email"],
      profile_image_url: data["picture"],
      raw_info: data
    }
  end
end
