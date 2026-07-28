# frozen_string_literal: true

class McpOauthAuthorizationCode < ApplicationRecord
  belongs_to :mcp_oauth_client
  belongs_to :person
  belongs_to :company_teammate, class_name: "CompanyTeammate"

  validates :code_digest, :redirect_uri, :code_challenge, :expires_at, presence: true

  scope :usable, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  def self.issue!(
    client:,
    person:,
    company_teammate:,
    redirect_uri:,
    code_challenge:,
    code_challenge_method: "S256",
    scope: "mcp",
    resource: nil,
    ttl: 10.minutes
  )
    raw = McpOauth::TokenDigest.generate_token("ogac_")
    record = create!(
      mcp_oauth_client: client,
      person: person,
      company_teammate: company_teammate,
      redirect_uri: redirect_uri,
      code_challenge: code_challenge,
      code_challenge_method: code_challenge_method,
      scope: scope,
      resource: resource,
      code_digest: McpOauth::TokenDigest.digest(raw),
      expires_at: ttl.from_now
    )
    [record, raw]
  end

  def self.consume(raw_code)
    record = usable.find_by(code_digest: McpOauth::TokenDigest.digest(raw_code))
    return nil if record.nil?

    record.update!(consumed_at: Time.current)
    record
  end

  def consumed?
    consumed_at.present?
  end
end
