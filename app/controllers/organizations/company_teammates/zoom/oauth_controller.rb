# frozen_string_literal: true

class Organizations::CompanyTeammates::Zoom::OauthController < ApplicationController
  include Organizations::ResolvesMeTeammateParam

  before_action :require_authentication
  before_action :set_organization, except: [:callback]
  before_action :set_organization_and_teammate_from_state, only: [:callback]
  before_action :set_teammate, only: %i[authorize disconnect]
  before_action :ensure_own_teammate!, only: %i[authorize disconnect]

  PROVIDER = "zoom"

  def authorize
    client_id = ENV["ZOOM_CLIENT_ID"]
    redirect_uri = zoom_oauth_redirect_uri
    if client_id.blank?
      redirect_to oauth_fallback_path_for_authorize, alert: "ZOOM_CLIENT_ID is not set."
      return
    end
    if redirect_uri.blank?
      redirect_to oauth_fallback_path_for_authorize, alert: "Zoom redirect URI is not configured."
      return
    end

    source = params[:source].presence || "identities"
    source = "consultOg" if source.in?(%w[consult_og consultOg])
    return_url = params[:return_to] || params[:return_url]
    return_url_encoded = return_url.present? ? Base64.urlsafe_encode64(return_url) : ""
    state = "#{@organization.id}_#{@teammate.id}_#{source}_#{return_url_encoded}"

    oauth_url =
      "https://zoom.us/oauth/authorize?" \
      "response_type=code" \
      "&client_id=#{CGI.escape(client_id.to_s)}" \
      "&redirect_uri=#{CGI.escape(redirect_uri)}" \
      "&state=#{CGI.escape(state)}"

    Rails.logger.info(
      "[Zoom OAuth] authorize client_id=#{client_id.to_s[0, 6]}… " \
      "redirect_uri=#{redirect_uri.inspect} url=#{oauth_url}"
    )

    redirect_to oauth_url, allow_other_host: true
  end

  def callback
    if params[:error].present?
      redirect_to oauth_fallback_path,
                  alert: "Zoom denied authorization: #{params[:error_description].presence || params[:error]}"
      return
    end

    code = params[:code]
    if code.blank?
      redirect_to oauth_fallback_path, alert: "Zoom connection was cancelled or failed."
      return
    end

    data = exchange_code_for_token(code)
    unless data["access_token"]
      redirect_to oauth_fallback_path,
                  alert: "Failed to connect Zoom: #{data['reason'] || data['error'] || 'Unknown error'}"
      return
    end

    profile = fetch_zoom_user_profile(data["access_token"])
    uid = profile[:uid]
    if uid.blank?
      redirect_to oauth_fallback_path, alert: "Failed to connect Zoom: missing user id from Zoom."
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
        "token_type" => data["token_type"] || "bearer"
      },
      "extra" => data.except("access_token", "refresh_token")
    }

    if identity.save
      redirect_to oauth_fallback_path,
                  notice: "Zoom (transcripts) connected. You can import transcripts from cloud recordings you hosted."
    else
      redirect_to oauth_fallback_path,
                  alert: "Failed to save Zoom identity: #{identity.errors.full_messages.join(', ')}"
    end
  rescue StandardError => e
    Rails.logger.error "Zoom OAuth error: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    redirect_to oauth_fallback_path, alert: "Failed to connect Zoom: #{e.message}"
  end

  def disconnect
    identity = @teammate.zoom_identity
    if identity&.destroy
      redirect_to disconnect_fallback_path, notice: "Zoom (transcripts) disconnected successfully."
    elsif identity.nil?
      redirect_to disconnect_fallback_path, alert: "No Zoom (transcripts) account connected to disconnect."
    else
      redirect_to disconnect_fallback_path, alert: "Failed to disconnect Zoom (transcripts). Please try again."
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
                alert: "You can only connect Zoom (transcripts) for yourself."
  end

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to connect Zoom."
  end

  def oauth_fallback_path
    return @return_url if @return_url.present?

    if @oauth_source == "consultOg"
      new_organization_possible_observation_consult_path(@organization)
    else
      organization_company_teammate_path(@organization, @teammate)
    end
  end

  def oauth_fallback_path_for_authorize
    params[:return_to].presence ||
      organization_company_teammate_path(@organization, @teammate)
  end

  def disconnect_fallback_path
    return_to = params[:return_to].presence
    return return_to if return_to.present?

    organization_company_teammate_path(@organization, @teammate)
  end

  def exchange_code_for_token(code)
    response = HTTP.basic_auth(user: ENV["ZOOM_CLIENT_ID"], pass: ENV["ZOOM_CLIENT_SECRET"])
                   .post(
                     "https://zoom.us/oauth/token",
                     form: {
                       grant_type: "authorization_code",
                       code: code,
                       redirect_uri: zoom_oauth_redirect_uri
                     }
                   )
    JSON.parse(response.body.to_s)
  end

  def zoom_oauth_redirect_uri
    ENV["ZOOM_REDIRECT_URI"].presence || zoom_oauth_callback_url
  end

  def fetch_zoom_user_profile(access_token)
    response = HTTP.auth("Bearer #{access_token}")
                   .get("https://api.zoom.us/v2/users/me")
    data = JSON.parse(response.body.to_s)
    name = [data["first_name"], data["last_name"]].compact.join(" ").presence ||
           data["display_name"].presence ||
           data["email"]

    {
      uid: data["id"],
      name: name,
      email: data["email"],
      profile_image_url: data["pic_url"],
      raw_info: data
    }
  end
end
