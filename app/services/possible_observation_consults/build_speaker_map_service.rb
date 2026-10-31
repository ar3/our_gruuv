# frozen_string_literal: true

module PossibleObservationConsults
  # Builds / refreshes speaker_map from transcript cues for prompt-debug consults.
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
      cues = Transcripts::ParseCuesService.call(raw: @consult.source_raw)
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
            prior.merge(
              "raw_label" => raw_label,
              "normalized_label" => meta["normalized"],
              "kind" => meta["kind"],
              "cue_count" => counts[raw_label]
            )
          elsif meta["kind"] == "audio_share"
            {
              "raw_label" => raw_label,
              "normalized_label" => meta["normalized"],
              "kind" => "audio_share",
              "status" => "ignore",
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
            status =
              if resolution[:company_teammate_id].present? && !resolution[:unknown]
                "resolved"
              elsif resolution[:company_teammate_id].present?
                "unknown"
              else
                "unknown"
              end
            {
              "raw_label" => raw_label,
              "normalized_label" => meta["normalized"],
              "kind" => meta["kind"],
              "status" => status,
              "company_teammate_id" => resolution[:company_teammate_id],
              "cue_count" => counts[raw_label],
              "alternates" => Array(resolution[:alternates]),
              "manual" => false
            }
          end

        labels[raw_label] = entry.stringify_keys
      end

      payload = { "version" => 1, "labels" => labels }
      @consult.update!(speaker_map: payload)
      payload
    end

    private

    def speaker_labels_hash
      hash = @consult.speaker_map.is_a?(Hash) ? @consult.speaker_map.with_indifferent_access : {}
      (hash[:labels] || {}).each_with_object({}) do |(key, value), memo|
        memo[key.to_s] = value
      end
    end

    def roster_teammates
      org_ids = @organization.self_and_descendants.map(&:id)
      CompanyTeammate.employed.where(organization_id: org_ids).includes(:person).to_a
    end
  end
end
