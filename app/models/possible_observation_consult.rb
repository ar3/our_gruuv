# frozen_string_literal: true

# Hub run for "Consult OG to Find OGOs" (paste / upload / Google Meet transcript import).
# Attribution for promoted drafts: ObservationTrigger — see docs/ogo-creation-attribution.md
class PossibleObservationConsult < ApplicationRecord
  EXTRACTIONS_VERSION = 1
  MAX_SOURCE_BYTES = 15.megabytes
  ALLOWED_CONTENT_TYPES = %w[
    text/plain
    text/vtt
    application/octet-stream
    application/json
    text/csv
  ].freeze
  PEOPLE_STATUSES = %w[suggested confirmed].freeze
  EXTRACTION_STATUSES = %w[ready pending processing completed failed].freeze
  FIRST_PASS_STATUSES = %w[ready pending processing completed failed].freeze

  belongs_to :organization
  belongs_to :creator_company_teammate, class_name: "CompanyTeammate",
                                       inverse_of: :possible_observation_consults_created

  has_one_attached :source_file
  has_many :og_consultations, as: :subject, dependent: :nullify

  validates :display_name, presence: true, length: { maximum: 255 }
  validates :people_status, inclusion: { in: PEOPLE_STATUSES }
  validates :extraction_status, inclusion: { in: EXTRACTION_STATUSES }
  validates :first_pass_status, inclusion: { in: FIRST_PASS_STATUSES }
  validate :source_present
  validate :source_file_constraints, if: -> { source_file.attached? }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :prompt_debug, -> { where(prompt_debug: true) }

  def extraction_items
    hash = extractions_hash
    Array(hash[:items]).map(&:with_indifferent_access)
  end

  # Frozen AI defaults from the last completed extraction (for prompt-debug diffs).
  def ai_extraction_items
    hash = extractions_hash
    Array(hash[:ai_items]).map(&:with_indifferent_access)
  end

  # Potential-OGO (candidate) counts for the index summary.
  def pogo_count
    extraction_items.size
  end

  def dismissed_pogo_count
    extraction_items.count { |item| item[:dismissed_at].present? }
  end

  def promoted_pogo_count
    extraction_items.count { |item| item[:observation_id].present? }
  end

  def processed_teammate_ids
    Array(extractions_hash[:processed_teammate_ids]).map(&:to_i).reject(&:zero?)
  end

  def replace_extraction_items!(items)
    update!(
      extractions: extractions_payload(
        items: items,
        ai_items: ai_extraction_items,
        processed_teammate_ids: processed_teammate_ids
      )
    )
  end

  def mark_processing!
    update!(
      extraction_status: "processing",
      extraction_error: nil,
      extractions: extractions_payload(items: [], ai_items: [], processed_teammate_ids: [])
    )
  end

  def heartbeat_processing!
    touch if extraction_status == "processing"
  end

  # Persist candidates for teammates finished so far (status stays processing).
  def persist_partial_extractions!(items:, processed_teammate_ids:)
    update!(
      extractions: extractions_payload(
        items: items,
        ai_items: [],
        processed_teammate_ids: Array(processed_teammate_ids).map(&:to_i)
      )
    )
  end

  def mark_completed!(items:, extraction_note: nil, processed_teammate_ids: nil)
    ids = processed_teammate_ids.nil? ? Array(confirmed_teammate_ids).map(&:to_i) : Array(processed_teammate_ids).map(&:to_i)
    frozen = items.map { |item| item.deep_dup }
    update!(
      extractions: extractions_payload(
        items: items,
        ai_items: frozen,
        processed_teammate_ids: ids
      ),
      extraction_status: "completed",
      extraction_error: extraction_note
    )
  end

  def mark_failed!(message)
    update!(extraction_status: "failed", extraction_error: message.to_s.truncate(10_000))
  end

  def confirmed_teammates
    ids = Array(confirmed_teammate_ids).map(&:to_i).reject(&:zero?)
    return CompanyTeammate.none if ids.empty?

    org_ids = organization.self_and_descendants.map(&:id)
    CompanyTeammate.where(id: ids, organization_id: org_ids)
  end

  def suggested_teammates
    ids = Array(suggested_teammate_ids).map(&:to_i).reject(&:zero?)
    return CompanyTeammate.none if ids.empty?

    org_ids = organization.self_and_descendants.map(&:id)
    CompanyTeammate.where(id: ids, organization_id: org_ids)
  end

  def plaintext
    if source_file.attached?
      Transcripts::PlaintextFromBlobService.call(blob: source_file.blob)
    else
      source_text.to_s
    end
  end

  # Raw upload/paste body (keeps VTT timing + speaker labels for debug cue parsing).
  def source_raw
    if source_file.attached?
      raw = source_file.download.force_encoding("UTF-8")
      raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    else
      source_text.to_s
    end
  end

  def speaker_map_labels
    hash = speaker_map.is_a?(Hash) ? speaker_map.with_indifferent_access : {}
    (hash[:labels] || {}).each_with_object({}) do |(key, value), memo|
      memo[key.to_s] = value.with_indifferent_access
    end
  end

  def cue_annotation_rows
    hash = cue_annotations.is_a?(Hash) ? cue_annotations.with_indifferent_access : {}
    (hash[:cues] || {}).each_with_object({}) do |(key, value), memo|
      memo[key.to_s] = value.with_indifferent_access
    end
  end

  # Step 2 / first-pass moments (merged captions + collapsed same-speaker ignores).
  # Falls back to live parse+merge before first pass has stored moments.
  def moment_cues
    hash = cue_annotations.is_a?(Hash) ? cue_annotations.with_indifferent_access : {}
    stored = Array(hash[:moments])
    return stored.map(&:with_indifferent_access) if stored.any?

    Transcripts::MomentCuesService.call(raw: source_raw)
  end

  def people_confirmed?
    people_status == "confirmed" && Array(confirmed_teammate_ids).any?
  end

  def first_pass_in_flight?
    first_pass_status.in?(%w[pending processing])
  end

  def first_pass_completed?
    first_pass_status == "completed"
  end

  # Step 3 keeps observer/observee editable so misses from Step 2 can be fixed
  # without going back. Rows that already became draft OGOs stay locked in the UI
  # via observation_id on the candidate row.
  def identities_locked?
    false
  end

  def mark_first_pass_pending!
    update!(first_pass_status: "pending", first_pass_error: nil)
  end

  def google_meet_source?
    source_metadata.is_a?(Hash) && source_metadata.with_indifferent_access[:provider].to_s == "google_meet"
  end

  def zoom_source?
    source_metadata.is_a?(Hash) && source_metadata.with_indifferent_access[:provider].to_s == "zoom"
  end

  # Returns [[teammate, items], ...] in confirmed order for finished people only.
  def extraction_groups_by_processed_teammate(teammates: nil)
    list = Array(teammates.presence || confirmed_teammates.includes(:person))
    by_id = list.index_by(&:id)
    items_by_subject = extraction_items.group_by { |item| item[:subject_company_teammate_id].to_i }

    ids = processed_teammate_ids
    if ids.empty? && extraction_status == "completed"
      ids = Array(confirmed_teammate_ids).map(&:to_i)
    end

    ids.filter_map do |tid|
      teammate = by_id[tid]
      next unless teammate

      [teammate, Array(items_by_subject[tid])]
    end
  end

  private

  def extractions_hash
    extractions.is_a?(Hash) ? extractions.with_indifferent_access : {}
  end

  def extractions_payload(items:, ai_items:, processed_teammate_ids:)
    {
      "version" => EXTRACTIONS_VERSION,
      "items" => items,
      "ai_items" => ai_items,
      "processed_teammate_ids" => Array(processed_teammate_ids).map(&:to_i)
    }
  end

  def source_present
    return if source_text.to_s.strip.present? || source_file.attached?

    errors.add(:base, "Paste text or upload a transcript file.")
  end

  def source_file_constraints
    blob = source_file.blob
    if blob.byte_size > MAX_SOURCE_BYTES
      errors.add(:source_file, "must be #{MAX_SOURCE_BYTES / 1.megabyte} MB or smaller")
    end
    ext = File.extname(blob.filename.to_s).downcase
    allowed_ext = %w[.txt .vtt .srt .json .csv]
    return if allowed_ext.include?(ext) || blob.content_type.in?(ALLOWED_CONTENT_TYPES)

    errors.add(:source_file, "must be a text transcript (.txt, .vtt, .srt, .json, or .csv)")
  end
end
