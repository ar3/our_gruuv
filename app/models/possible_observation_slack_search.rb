# frozen_string_literal: true

class PossibleObservationSlackSearch < ApplicationRecord
  RAW_RESULTS_VERSION = 1
  EXTRACTIONS_VERSION = 1
  ALLOWED_WINDOW_DAYS = [30, 90, 180].freeze
  DEFAULT_WINDOW_DAYS = 90
  MAX_MESSAGES = 50

  belongs_to :organization
  belongs_to :creator_company_teammate, class_name: "CompanyTeammate",
                                        inverse_of: :possible_observation_slack_searches_created
  belongs_to :subject_company_teammate, class_name: "CompanyTeammate",
                                       inverse_of: :possible_observation_slack_searches_as_subject

  validates :display_name, presence: true, length: { maximum: 255 }
  validates :window_days, inclusion: { in: ALLOWED_WINDOW_DAYS }
  validates :search_status, presence: true, inclusion: { in: %w[pending processing completed failed] }
  validates :extraction_status, presence: true, inclusion: { in: %w[pending processing completed failed] }
  validates :query, length: { maximum: 1000 }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :for_subject, ->(teammate) { where(subject_company_teammate_id: teammate.id) }

  def raw_messages
    hash = raw_results.is_a?(Hash) ? raw_results.with_indifferent_access : {}
    Array(hash[:messages]).map(&:with_indifferent_access)
  end

  def raw_messages_count
    raw_messages.size
  end

  def extraction_items
    hash = extractions.is_a?(Hash) ? extractions.with_indifferent_access : {}
    Array(hash[:items]).map(&:with_indifferent_access)
  end

  def mark_search_processing!
    update!(search_status: "processing", search_error: nil)
  end

  def mark_search_completed!(query:, raw_results:)
    update!(
      query: query,
      raw_results: raw_results,
      search_status: "completed",
      search_error: nil
    )
  end

  def mark_search_failed!(message)
    update!(search_status: "failed", search_error: message.to_s.truncate(10_000))
  end

  def deletable?
    true
  end
end
