# frozen_string_literal: true

# Bearer tokens for MCP HTTP clients. Bound to a Person + CompanyTeammate so tools
# run as that teammate (same Pundit identity as the UI). Full OAuth AS can mint
# these later; v1 issues them after an authenticated Google session.
class McpAccessToken < ApplicationRecord
  PREFIX = "ogmcp_"

  belongs_to :person
  belongs_to :company_teammate, class_name: "CompanyTeammate"

  validates :token_digest, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token.to_s)
  end

  # Returns [record, raw_token_with_prefix] — raw is shown once at create time.
  def self.issue!(person:, company_teammate:, name: "Claude Desktop", expires_at: nil)
    raise ArgumentError, "teammate person mismatch" unless company_teammate.person_id == person.id

    raw = "#{PREFIX}#{SecureRandom.urlsafe_base64(32)}"
    record = create!(
      person: person,
      company_teammate: company_teammate,
      token_digest: digest(raw),
      name: name.presence || "Claude Desktop",
      expires_at: expires_at
    )
    [record, raw]
  end

  def self.authenticate(raw_token)
    return nil if raw_token.blank?

    token = active.find_by(token_digest: digest(raw_token))
    return nil if token.nil?

    token.touch_last_used!
    token
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  def active?
    !revoked? && (expires_at.nil? || expires_at > Time.current)
  end
end
