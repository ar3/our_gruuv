# frozen_string_literal: true

class McpOauthAccessToken < ApplicationRecord
  PREFIX = "ogoat_"

  belongs_to :mcp_oauth_client
  belongs_to :person
  belongs_to :company_teammate, class_name: "CompanyTeammate"

  validates :token_digest, :expires_at, presence: true

  scope :active, -> {
    where(revoked_at: nil).where("expires_at > ?", Time.current)
  }

  def self.issue!(client:, person:, company_teammate:, scope:, resource: nil, ttl: 1.hour)
    raw = McpOauth::TokenDigest.generate_token(PREFIX)
    record = create!(
      mcp_oauth_client: client,
      person: person,
      company_teammate: company_teammate,
      scope: scope,
      resource: resource,
      token_digest: McpOauth::TokenDigest.digest(raw),
      expires_at: ttl.from_now
    )
    [record, raw]
  end

  def self.authenticate(raw_token)
    return nil if raw_token.blank?

    token = active.find_by(token_digest: McpOauth::TokenDigest.digest(raw_token))
    return nil if token.nil?

    token.update_column(:last_used_at, Time.current)
    token
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
