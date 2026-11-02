# frozen_string_literal: true

# Per-runner enrollment: auto-refresh Slack pOGOs about a subject every 14 days.
# source: hub (locked while hub on) | manual (independent opt-in).
class SlackPogoAutoRefreshEnrollment < ApplicationRecord
  SOURCE_HUB = "hub"
  SOURCE_MANUAL = "manual"
  SOURCES = [SOURCE_HUB, SOURCE_MANUAL].freeze
  REFRESH_EVERY = 14.days
  WINDOW_DAYS = 14

  belongs_to :organization
  belongs_to :runner_company_teammate, class_name: "CompanyTeammate",
                                       inverse_of: :slack_pogo_auto_refresh_enrollments_as_runner
  belongs_to :subject_company_teammate, class_name: "CompanyTeammate",
                                        inverse_of: :slack_pogo_auto_refresh_enrollments_as_subject

  validates :source, inclusion: { in: SOURCES }
  validates :subject_company_teammate_id, uniqueness: { scope: :runner_company_teammate_id }

  scope :due, lambda {
    where("last_refreshed_at IS NULL OR last_refreshed_at <= ?", REFRESH_EVERY.ago)
  }
  scope :hub, -> { where(source: SOURCE_HUB) }
  scope :manual, -> { where(source: SOURCE_MANUAL) }

  def hub?
    source == SOURCE_HUB
  end

  def manual?
    source == SOURCE_MANUAL
  end

  def due?
    last_refreshed_at.nil? || last_refreshed_at <= REFRESH_EVERY.ago
  end

  def mark_refreshed!
    update!(last_refreshed_at: Time.current)
  end
end
