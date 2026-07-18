# frozen_string_literal: true

class PossibleObservationSlackSearch < ApplicationRecord
  RAW_RESULTS_VERSION = 1
  EXTRACTIONS_VERSION = 1
  ALLOWED_WINDOW_DAYS = [30, 90, 180].freeze
  DEFAULT_WINDOW_DAYS = 90
  # Slack search.messages max per page; we paginate until Slack reports no more pages.
  PAGE_SIZE = 100
  MAX_PAGES = 100 # Slack API hard max for the page param

  belongs_to :organization
  belongs_to :creator_company_teammate, class_name: "CompanyTeammate",
                                        inverse_of: :possible_observation_slack_searches_created
  belongs_to :subject_company_teammate, class_name: "CompanyTeammate",
                                       inverse_of: :possible_observation_slack_searches_as_subject

  has_one_attached :raw_results_file
  has_many :og_consultations, as: :subject, dependent: :nullify

  validates :display_name, presence: true, length: { maximum: 255 }
  validates :window_days, inclusion: { in: ALLOWED_WINDOW_DAYS }
  validates :search_status, presence: true, inclusion: { in: %w[pending processing completed failed] }
  validates :extraction_status, presence: true, inclusion: { in: %w[ready pending processing completed failed] }
  validates :query, length: { maximum: 1000 }
  validates :messages_count, numericality: { greater_than_or_equal_to: 0 }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :for_subject, ->(teammate) { where(subject_company_teammate_id: teammate.id) }

  def raw_messages
    payload = raw_results_payload
    Array(payload[:messages]).map(&:with_indifferent_access)
  end

  def raw_messages_count
    return messages_count if messages_count.positive? || search_status == "completed"

    raw_messages.size
  end

  def raw_results_payload
    if raw_results_file.attached?
      JSON.parse(raw_results_file.download).with_indifferent_access
    else
      # Legacy rows stored the full payload in jsonb before ActiveStorage.
      (raw_results.is_a?(Hash) ? raw_results : {}).with_indifferent_access
    end
  rescue JSON::ParserError, ActiveStorage::FileNotFoundError => e
    Rails.logger.error("PossibleObservationSlackSearch##{id} raw_results_payload: #{e.class} #{e.message}")
    {}.with_indifferent_access
  end

  def extraction_items
    hash = extractions.is_a?(Hash) ? extractions.with_indifferent_access : {}
    Array(hash[:items])
      .map(&:with_indifferent_access)
      .sort_by { |item| [-item[:confidence].to_f, item[:ts].to_s] }
  end

  def mark_extraction_processing!
    update!(extraction_status: "processing", extraction_error: nil)
  end

  def heartbeat_extraction_processing!
    touch if extraction_status == "processing"
  end

  def mark_extraction_completed!(items:, extraction_note: nil)
    update!(
      extractions: { "version" => EXTRACTIONS_VERSION, "items" => sort_extraction_items(items) },
      extraction_status: "completed",
      extraction_error: extraction_note
    )
  end

  def mark_extraction_failed!(message)
    update!(extraction_status: "failed", extraction_error: message.to_s.truncate(10_000))
  end

  def replace_extraction_items!(items)
    update!(extractions: { "version" => EXTRACTIONS_VERSION, "items" => sort_extraction_items(items) })
  end

  def sort_extraction_items(items)
    Array(items).sort_by { |item| h = item.with_indifferent_access; [-h[:confidence].to_f, h[:ts].to_s] }
  end
  private :sort_extraction_items

  def mark_search_processing!
    update!(search_status: "processing", search_error: nil)
  end

  def heartbeat_search_processing!
    touch if search_status == "processing"
  end

  def mark_search_completed!(query:, messages:, meta:)
    attach_raw_results!(query: query, messages: messages, meta: meta)
    update!(
      query: query.to_s.truncate(1000),
      messages_count: messages.size,
      raw_results: {
        "version" => RAW_RESULTS_VERSION,
        "stored_in" => "active_storage",
        "messages_count" => messages.size,
        "slack_total" => meta[:slack_total],
        "pages_fetched" => meta[:pages_fetched],
        "fetched_at" => meta[:fetched_at],
        "queries" => meta[:queries]
      }.compact,
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

  def search_queries
    payload = raw_results_payload
    Array(payload[:queries]).presence ||
      Array(raw_results.is_a?(Hash) ? raw_results["queries"] : nil).presence ||
      (query.present? ? [{ "kind" => "legacy", "query" => query }] : [])
  end

  private

  def attach_raw_results!(query:, messages:, meta:)
    payload = {
      "version" => RAW_RESULTS_VERSION,
      "query" => query,
      "queries" => meta[:queries],
      "window_days" => window_days,
      "fetched_at" => meta[:fetched_at],
      "slack_total" => meta[:slack_total],
      "pages_fetched" => meta[:pages_fetched],
      "messages" => messages
    }.compact
    raw_results_file.purge if raw_results_file.attached?
    raw_results_file.attach(
      io: StringIO.new(JSON.generate(payload)),
      filename: "slack_search_#{id}_raw_results.json",
      content_type: "application/json"
    )
  end
end
