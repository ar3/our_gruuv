# frozen_string_literal: true

module PossibleObservationConsults
  # Writes first-pass LLM output into speaker_map + cue_annotations.
  # Expands multi-moment LLM splits into separate Step 2 rows, then collapses
  # consecutive same-speaker ignores. Prefers teammate IDs from the first-pass
  # call; deterministic name match only when an id is blank (no per-label LLM).
  class ApplyFirstPassResults
    def self.call(consult:, cues:, llm_by_cue_id:)
      new(consult: consult, cues: cues, llm_by_cue_id: llm_by_cue_id).call
    end

    def initialize(consult:, cues:, llm_by_cue_id:)
      @consult = consult
      @cues = Array(cues).map { |cue| cue.with_indifferent_access }
      @llm_by_cue_id = llm_by_cue_id || {}
      @organization = consult.organization
    end

    def call
      teammates = roster_teammates
      teammates_by_id = teammates.index_by(&:id)
      labels = {}
      annotations = {}
      expanded_cues = []

      @cues.each do |cue|
        llm_payload = (@llm_by_cue_id[cue[:id].to_s] || {}).stringify_keys
        moments = moments_for(llm_payload, cue)

        moments.each_with_index do |llm, index|
          llm = llm.stringify_keys
          moment_id =
            if moments.size > 1
              "#{cue[:id]}-m#{index + 1}"
            else
              cue[:id].to_s
            end

          speaker = cue[:speaker_label].to_s
          observer_label = llm["observer_label"].presence || speaker
          observee_labels = Array(llm["observee_labels"])
          audio = cue[:kind].to_s == "audio_share"
          ogo_worthy = audio ? false : ActiveModel::Type::Boolean.new.cast(llm["ogo_worthy"])
          excerpt = faithful_excerpt(cue_text: cue[:text].to_s, proposed: llm["excerpt"])

          observer_resolution = resolve_person(
            label: observer_label,
            preferred_id: llm["observer_company_teammate_id"],
            teammates: teammates,
            teammates_by_id: teammates_by_id
          )
          primary_observee_id = Array(llm["observee_company_teammate_ids"]).first
          observee_resolution =
            if primary_observee_id.present? || observee_labels.any?
              resolve_person(
                label: observee_labels.first,
                preferred_id: primary_observee_id,
                teammates: teammates,
                teammates_by_id: teammates_by_id
              )
            else
              { company_teammate_id: nil, unknown: true, alternates: [] }
            end

          observee_ids = Array(llm["observee_company_teammate_ids"]).filter_map { |raw|
            id = raw.to_i
            id if teammates_by_id.key?(id)
          }.uniq
          if observee_ids.empty?
            observee_ids = observee_labels.filter_map { |label|
              resolve_person(
                label: label,
                preferred_id: nil,
                teammates: teammates,
                teammates_by_id: teammates_by_id
              )[:company_teammate_id]
            }.uniq
          end

          if speaker.present?
            labels[speaker] ||= {
              "raw_label" => speaker,
              "normalized_label" => Transcripts::NormalizeSpeakerLabel.call(speaker)["normalized"],
              "kind" => cue[:kind].to_s,
              "certainty" => observer_resolution[:unknown] || observer_resolution[:company_teammate_id].blank? ? "uncertain" : "certain",
              "company_teammate_id" => observer_resolution[:company_teammate_id],
              "cue_count" => 0,
              "alternates" => Array(observer_resolution[:alternates]),
              "manual" => false
            }
            if labels[speaker]["company_teammate_id"].blank? && observer_resolution[:company_teammate_id].present?
              labels[speaker]["company_teammate_id"] = observer_resolution[:company_teammate_id]
              labels[speaker]["certainty"] = observer_resolution[:unknown] ? "uncertain" : "certain"
              labels[speaker]["alternates"] = Array(observer_resolution[:alternates])
            end
          end

          expanded_cues << cue.merge(
            "id" => moment_id,
            "text" => excerpt,
            "parent_cue_id" => cue[:id].to_s,
            "moment_index" => index + 1,
            "merged" => ActiveModel::Type::Boolean.new.cast(cue[:merged]) || moments.size > 1
          )

          annotations[moment_id] = {
            "cue_status" => ogo_worthy ? "ogo_worthy" : "ignore",
            "ogo_worthy" => ogo_worthy,
            "first_pass_reason" => llm["reason"].to_s,
            "observer_label" => observer_label,
            "observee_labels" => observee_labels,
            "observee_certainty" =>
              if observee_resolution[:company_teammate_id].blank?
                "uncertain"
              elsif observee_resolution[:unknown]
                "uncertain"
              else
                "certain"
              end,
            "observee_company_teammate_id" => observee_resolution[:company_teammate_id],
            "observee_company_teammate_ids" => observee_ids
          }
        end
      end

      collapsed = CollapseIgnoredMoments.call(cues: expanded_cues, annotations: annotations)
      collapsed_cues = collapsed[:cues]
      collapsed_annotations = collapsed[:annotations]
      labels = recount_labels(labels, collapsed_cues)

      @consult.update!(
        speaker_map: { "version" => 1, "labels" => labels },
        cue_annotations: {
          "version" => 1,
          "cues" => collapsed_annotations,
          "moments" => collapsed_cues
        },
        first_pass_status: "completed",
        first_pass_error: nil
      )
    end

    private

    def faithful_excerpt(cue_text:, proposed:)
      text = cue_text.to_s
      candidate = proposed.to_s.strip
      return text if candidate.blank?
      return candidate if text.include?(candidate)

      # Whitespace-flexible containment still must be drawn from this cue.
      tokens = candidate.split(/\s+/).map { |token| Regexp.escape(token) }.reject(&:blank?)
      if tokens.any?
        match = text.match(Regexp.new(tokens.join('\s+'), Regexp::IGNORECASE | Regexp::MULTILINE))
        return match[0] if match
      end

      text
    end

    def moments_for(llm_payload, cue)
      moments = Array(llm_payload["moments"])
      return moments if moments.any?

      # Backward-compatible flat payload from older stubs/calls.
      if llm_payload.key?("ogo_worthy") || llm_payload.key?("observee_labels")
        return [llm_payload.merge("excerpt" => cue[:text].to_s)]
      end

      [{
        "ogo_worthy" => false,
        "observer_label" => cue[:speaker_label].to_s,
        "observee_labels" => [],
        "excerpt" => cue[:text].to_s,
        "reason" => "missing_first_pass_payload"
      }]
    end

    def resolve_person(label:, preferred_id:, teammates:, teammates_by_id:)
      id = preferred_id.to_i
      if id.positive? && teammates_by_id.key?(id)
        return { company_teammate_id: id, unknown: false, alternates: [] }
      end

      return { company_teammate_id: nil, unknown: true, alternates: [] } if label.blank?

      Transcripts::TeammateResolverService.call(
        organization: @organization,
        label: Transcripts::NormalizeSpeakerLabel.call(label)["normalized"],
        teammates: teammates,
        allow_llm: false
      )
    end

    def recount_labels(labels, cues)
      counts = Hash.new(0)
      cues.each do |cue|
        speaker = cue.with_indifferent_access[:speaker_label].to_s
        counts[speaker] += 1 if speaker.present?
      end
      labels.each do |speaker, entry|
        entry["cue_count"] = counts[speaker].to_i
      end
      labels
    end

    def roster_teammates
      org_ids = @organization.self_and_descendants.map(&:id)
      CompanyTeammate.employed.where(organization_id: org_ids).includes(:person).to_a
    end
  end
end
