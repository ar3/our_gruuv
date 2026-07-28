# frozen_string_literal: true

class McpOauthClient < ApplicationRecord
  has_many :mcp_oauth_authorization_codes, dependent: :destroy
  has_many :mcp_oauth_access_tokens, dependent: :destroy
  has_many :mcp_oauth_refresh_tokens, dependent: :destroy

  validates :client_id, presence: true, uniqueness: true
  validates :token_endpoint_auth_method, presence: true
  validate :redirect_uris_present

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.find_active(client_id)
    active.find_by(client_id: client_id)
  end

  def public_client?
    token_endpoint_auth_method == "none"
  end

  def allows_redirect_uri?(uri)
    McpOauth::RedirectUri.allowed?(requested: uri, registered: redirect_uris)
  end

  def as_registration_response
    {
      client_id: client_id,
      client_id_issued_at: created_at.to_i,
      client_name: client_name,
      redirect_uris: redirect_uris,
      grant_types: grant_types,
      response_types: response_types,
      token_endpoint_auth_method: token_endpoint_auth_method,
      client_uri: client_uri,
      logo_uri: logo_uri
    }.compact
  end

  private

  def redirect_uris_present
    errors.add(:redirect_uris, "must include at least one URI") if Array(redirect_uris).blank?
  end
end
