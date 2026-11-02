# frozen_string_literal: true

module PossibleObservationConsults
  # Applies consult.speaker_map + per-cue observer overrides onto candidate observer fields.
  class ApplySpeakerMapToItems
    def self.call(items:, speaker_map:, cue_annotations: nil, cues: nil)
      new(
        items: items,
        speaker_map: speaker_map,
        cue_annotations: cue_annotations,
        cues: cues
      ).call
    end

    def initialize(items:, speaker_map:, cue_annotations: nil, cues: nil)
      @items = Array(items)
      @labels = begin
        hash = speaker_map.is_a?(Hash) ? speaker_map.with_indifferent_access : {}
        (hash[:labels] || {}).each_with_object({}) do |(key, value), memo|
          memo[key.to_s] = value.with_indifferent_access
        end
      end
      @cue_annotations = begin
        hash = cue_annotations.is_a?(Hash) ? cue_annotations.with_indifferent_access : {}
        (hash[:cues] || hash).each_with_object({}) do |(key, value), memo|
          next unless value.is_a?(Hash)

          memo[key.to_s] = value.with_indifferent_access
        end
      end
      @cues = Array(cues)
    end

    def call
      cue_links = if @cues.any? && @cue_annotations.any?
                    MatchCuesToItems.call(cues: @cues, items: @items)
                  else
                    {}
                  end

      @items.map do |raw|
        item = raw.respond_to?(:with_indifferent_access) ? raw.with_indifferent_access : raw.stringify_keys
        item = item.to_h.stringify_keys
        apply_observer!(item, cue_links)
        item
      end
    end

    private

    def apply_observer!(item, cue_links)
      cue_ids = Array(cue_links[item["id"].to_s])
      cue_ids.each do |cue_id|
        annotation = @cue_annotations[cue_id.to_s]
        next if annotation.blank?
        next if annotation[:observer_company_teammate_id].blank?

        item["responder_company_teammate_id"] = annotation[:observer_company_teammate_id].to_i
        item["observer_unknown"] = annotation[:observer_certainty].to_s != "certain"
        item["observer_alternates"] = []
        return
      end

      label = item["speaker_label"].to_s
      mapping = @labels[label]
      return unless mapping

      if mapping[:company_teammate_id].present?
        item["responder_company_teammate_id"] = mapping[:company_teammate_id].to_i
        item["observer_unknown"] = mapping[:certainty].to_s != "certain" && mapping[:status].to_s != "resolved"
        item["observer_alternates"] = Array(mapping[:alternates])
      elsif mapping[:status].to_s == "ignore" || mapping[:kind].to_s == "audio_share"
        item["responder_company_teammate_id"] = nil
        item["observer_unknown"] = true
        item["observer_alternates"] = []
      end
    end
  end
end
