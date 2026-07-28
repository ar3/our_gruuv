# frozen_string_literal: true

class McpOauthRefreshToken < ApplicationRecord
  PREFIX = "ogrt_"

  belongs_to :mcp_oauth_client
  belongs_to :person
  belongs_to :company_teammate, class_name: "CompanyTeammate"

  validates :token_digest, presence: true

  scope :active, -> {
    where(revoked_at: nil, rotated_at: nil)
      .where("expires_at IS NULL OR expires_at > ?", Time.current)
  }

  def self.issue!(client:, person:, company_teammate:, scope:, resource: nil, ttl: 30.days)
    raw = McpOauth::TokenDigest.generate_token(PREFIX)
    record = create!(
      mcp_oauth_client: client,
      person: person,
      company_teammate: company_teammate,
      scope: scope,
      resource: resource,
      token_digest: McpOauth::TokenDigest.digest(raw),
      expires_at: ttl&.from_now
    )
    [record, raw]
  end

  def self.find_active(raw_token)
    return nil if raw_token.blank?

    active.find_by(token_digest: McpOauth::TokenDigest.digest(raw_token))
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def mark_rotated!
    update!(rotated_at: Time.current, revoked_at: Time.current)
  end
end
