# frozen_string_literal: true

class PossibleObservationTranscript < ApplicationRecord
  EXTRACTIONS_VERSION = 1
  MAX_TRANSCRIPT_BYTES = 15.megabytes
  ALLOWED_CONTENT_TYPES = %w[
    text/plain
    text/vtt
    application/octet-stream
    application/json
    text/csv
  ].freeze

  belongs_to :organization
  belongs_to :creator_company_teammate, class_name: 'CompanyTeammate', inverse_of: :possible_observation_transcripts_created
  has_many :feedback_requests, dependent: :restrict_with_exception

  has_one_attached :transcript_file

  validates :display_name, presence: true, length: { maximum: 255 }
  validates :extraction_status, presence: true, inclusion: { in: %w[pending processing completed failed] }

  validate :transcript_file_constraints, if: -> { transcript_file.attached? }

  scope :recent_first, -> { order(created_at: :desc) }

  def extraction_items
    hash = extractions.is_a?(Hash) ? extractions.with_indifferent_access : {}
    Array(hash[:items]).map(&:with_indifferent_access)
  end

  def feedback_requests_created_count
    feedback_requests.count
  end

  def mark_processing!
    update!(extraction_status: 'processing', extraction_error: nil)
  end

  def heartbeat_processing!
    touch if extraction_status == 'processing'
  end

  def mark_completed!(items:, extraction_note: nil)
    update!(
      extractions: { 'version' => EXTRACTIONS_VERSION, 'items' => items },
      extraction_status: 'completed',
      extraction_error: extraction_note
    )
  end

  def mark_failed!(message)
    update!(extraction_status: 'failed', extraction_error: message.to_s.truncate(10_000))
  end

  def replace_extraction_items!(items)
    update!(
      extractions: { 'version' => EXTRACTIONS_VERSION, 'items' => items }
    )
  end

  def plaintext_byte_size
    transcript_file.attached? ? transcript_file.blob.byte_size : 0
  end

  def deletable?
    feedback_requests.none?
  end

  private

  def transcript_file_constraints
    blob = transcript_file.blob
    if blob.byte_size > MAX_TRANSCRIPT_BYTES
      errors.add(:transcript_file, "must be #{MAX_TRANSCRIPT_BYTES / 1.megabyte} MB or smaller")
    end
    ext = File.extname(blob.filename.to_s).downcase
    allowed_ext = %w[.txt .vtt .srt .json .csv]
    return if allowed_ext.include?(ext) || blob.content_type.in?(ALLOWED_CONTENT_TYPES)

    errors.add(:transcript_file, 'use a transcript export (.txt, .vtt, .srt, .json, or .csv)')
  end
end
