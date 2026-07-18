# frozen_string_literal: true

# A ≤500-message slice of a Slack OGO search. Owns review candidates and is the
# OgConsultation subject for ogo_search_slack runs. Message payloads stay on the parent search.
class PossibleObservationSlackSearchBatch < ApplicationRecord
  EXTRACTIONS_VERSION = PossibleObservationSlackSearch::EXTRACTIONS_VERSION

  belongs_to :possible_observation_slack_search, inverse_of: :message_batches
  has_many :og_consultations, as: :subject, dependent: :nullify

  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :messages_count, numericality: { greater_than_or_equal_to: 0 }
  validates :extraction_status, presence: true, inclusion: { in: %w[ready pending processing completed failed] }

  scope :in_position_order, -> { order(:position) }

  delegate :organization, :creator_company_teammate, :subject_company_teammate,
           to: :possible_observation_slack_search

  def messages
    keys = Array(message_keys).map(&:to_s)
    return [] if keys.empty?

    by_key = {}
    possible_observation_slack_search.raw_messages.each do |message|
      key = self.class.message_key(message)
      by_key[key] = message if keys.include?(key)
    end
    keys.filter_map { |key| by_key[key] }
  end

  def self.message_key(message)
    m = message.with_indifferent_access
    "#{m[:channel_id]}|#{m[:ts]}"
  end

  def batches_total
    @batches_total ||= possible_observation_slack_search.message_batches.count
  end

  def display_label
    range = date_range_label
    slice = slice_size_label
    if range.present?
      "Consultation #{position} of #{batches_total}; #{slice} (#{range})"
    else
      "Consultation #{position} of #{batches_total}; #{slice}"
    end
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

  private

  def slice_size_label
    if position == 1
      "Newest #{messages_count}"
    elsif position == batches_total
      "Remaining #{messages_count}"
    else
      "Next #{messages_count}"
    end
  end

  def date_range_label
    return if oldest_ts.blank? || newest_ts.blank?

    oldest = format_ts(oldest_ts)
    newest = format_ts(newest_ts)
    return if oldest.blank? || newest.blank?
    return oldest if oldest == newest

    "#{oldest}–#{newest}"
  end

  def format_ts(ts)
    Time.zone.at(ts.to_f).strftime("%b %-d")
  rescue ArgumentError, TypeError, RangeError
    nil
  end

  def sort_extraction_items(items)
    Array(items).sort_by { |item| h = item.with_indifferent_access; [-h[:confidence].to_f, h[:ts].to_s] }
  end
end
