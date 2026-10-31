# frozen_string_literal: true

module PossibleObservationConsults
  # Applies consult.speaker_map resolutions onto candidate observer fields.
  class ApplySpeakerMapToItems
    def self.call(items:, speaker_map:)
      new(items: items, speaker_map: speaker_map).call
    end

    def initialize(items:, speaker_map:)
      @items = Array(items)
      @labels = begin
        hash = speaker_map.is_a?(Hash) ? speaker_map.with_indifferent_access : {}
        (hash[:labels] || {}).each_with_object({}) do |(key, value), memo|
          memo[key.to_s] = value.with_indifferent_access
        end
      end
    end

    def call
      @items.map do |raw|
        item = raw.respond_to?(:with_indifferent_access) ? raw.with_indifferent_access : raw.stringify_keys
        item = item.to_h.stringify_keys
        label = item["speaker_label"].to_s
        mapping = @labels[label]
        next item unless mapping

        case mapping[:status].to_s
        when "ignore"
          item["responder_company_teammate_id"] = nil
          item["observer_unknown"] = true
          item["observer_alternates"] = []
        when "resolved", "unknown"
          if mapping[:company_teammate_id].present?
            item["responder_company_teammate_id"] = mapping[:company_teammate_id].to_i
            item["observer_unknown"] = mapping[:status].to_s != "resolved"
            item["observer_alternates"] = Array(mapping[:alternates])
          end
        end
        item
      end
    end
  end
end
