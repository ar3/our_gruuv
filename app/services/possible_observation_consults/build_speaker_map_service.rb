# frozen_string_literal: true

module PossibleObservationConsults
  # Cheap first pass: parse cues, resolve speaker labels → teammates (name match / light LLM),
  # and seed per-cue OGO-worthy vs ignore + observee placeholders.
  class BuildSpeakerMapService
    def self.call(consult:, organization: nil, preserve_overrides: true)
      new(consult: consult, organization: organization, preserve_overrides: preserve_overrides).call
    end

    def initialize(consult:, organization:, preserve_overrides:)
      @consult = consult
      @organization = organization || consult.organization
      @preserve_overrides = preserve_overrides
    end

    def call
      cues = Transcripts::MomentCuesService.call(raw: @consult.source_raw)
      counts = Hash.new(0)
      cues.each { |cue| counts[cue["speaker_label"].to_s] += 1 if cue["speaker_label"].present? }

      existing = speaker_labels_hash
      teammates = roster_teammates
      labels = {}

      counts.keys.sort_by { |label| [-counts[label], label.downcase] }.each do |raw_label|
        meta = Transcripts::NormalizeSpeakerLabel.call(raw_label)
        prior = existing[raw_label] || existing[meta["normalized"]] || {}
        prior = prior.with_indifferent_access

        entry =
          if @preserve_overrides && prior["manual"]
            normalize_label_entry(
              prior.merge(
                "raw_label" => raw_label,
                "normalized_label" => meta["normalized"],
                "kind" => meta["kind"],
                "cue_count" => counts[raw_label]
              )
            )
          elsif meta["kind"] == "audio_share"
            {
              "raw_label" => raw_label,
              "normalized_label" => meta["normalized"],
              "kind" => "audio_share",
              "certainty" => "uncertain",
              "company_teammate_id" => nil,
              "cue_count" => counts[raw_label],
              "alternates" => [],
              "manual" => false
            }
          else
            resolution = Transcripts::TeammateResolverService.call(
              organization: @organization,
              label: meta["normalized"],
              teammates: teammates
            )
            certainty =
              if resolution[:company_teammate_id].present? && !resolution[:unknown]
                "certain"
              else
                "uncertain"
              end
            {
              "raw_label" => raw_label,
              "normalized_label" => meta["normalized"],
              "kind" => meta["kind"],
              "certainty" => certainty,
              "company_teammate_id" => resolution[:company_teammate_id],
              "cue_count" => counts[raw_label],
              "alternates" => Array(resolution[:alternates]),
              "manual" => false
            }
          end

        labels[raw_label] = entry.stringify_keys
      end

      cue_annotations = build_cue_annotations(cues)
      payload = { "version" => 1, "labels" => labels }
      @consult.update!(speaker_map: payload, cue_annotations: cue_annotations)
      payload
    end

    private

    def normalize_label_entry(entry)
      entry = entry.stringify_keys
      certainty = entry["certainty"].presence
      unless %w[certain uncertain].include?(certainty)
        certainty =
          case entry["status"].to_s
          when "resolved" then "certain"
          else "uncertain"
          end
      end
      entry.except("status").merge("certainty" => certainty)
    end

    def speaker_labels_hash
      hash = @consult.speaker_map.is_a?(Hash) ? @consult.speaker_map.with_indifferent_access : {}
      (hash[:labels] || {}).each_with_object({}) do |(key, value), memo|
        memo[key.to_s] = value
      end
    end

    def existing_cue_annotations
      hash = @consult.cue_annotations.is_a?(Hash) ? @consult.cue_annotations.with_indifferent_access : {}
      (hash[:cues] || {}).each_with_object({}) do |(key, value), memo|
        memo[key.to_s] = value
      end
    end

    def build_cue_annotations(cues)
      prior = existing_cue_annotations
      rows = {}
      cues.each do |cue|
        cue_id = cue["id"].to_s
        if @preserve_overrides && prior[cue_id].present?
          rows[cue_id] = normalize_cue_entry(prior[cue_id])
          next
        end

        default_cue_status = cue["kind"].to_s == "audio_share" ? "ignore" : "ogo_worthy"
        rows[cue_id] = {
          "cue_status" => default_cue_status,
          "observee_certainty" => "uncertain",
          "observee_company_teammate_id" => nil
        }
      end
      { "version" => 1, "cues" => rows }
    end

    def normalize_cue_entry(entry)
      entry = entry.stringify_keys
      cue_status = entry["cue_status"].presence
      unless %w[ogo_worthy ignore].include?(cue_status)
        cue_status =
          case entry["observee_status"].to_s
          when "ignore", "team_or_none" then "ignore"
          else "ogo_worthy"
          end
        cue_status = "ignore" if entry["status"].to_s == "ignore"
      end
      observee_certainty = entry["observee_certainty"].presence
      unless %w[certain uncertain].include?(observee_certainty)
        observee_certainty =
          case entry["observee_status"].to_s
          when "resolved" then "certain"
          else "uncertain"
          end
      end
      {
        "cue_status" => cue_status,
        "observee_certainty" => observee_certainty,
        "observee_company_teammate_id" => entry["observee_company_teammate_id"]
      }
    end

    def roster_teammates
      org_ids = @organization.self_and_descendants.map(&:id)
      CompanyTeammate.employed.where(organization_id: org_ids).includes(:person).to_a
    end
  end
end
