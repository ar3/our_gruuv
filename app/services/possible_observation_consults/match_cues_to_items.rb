# frozen_string_literal: true

module PossibleObservationConsults
  # Links extraction candidates to transcript cues by quote overlap (debug UI).
  class MatchCuesToItems
    MIN_FRAGMENT = 24

    def self.call(cues:, items:)
      new(cues: cues, items: items).call
    end

    def initialize(cues:, items:)
      @cues = Array(cues).map { |cue| cue.with_indifferent_access }
      @items = Array(items).map { |item| item.with_indifferent_access }
    end

    def call
      cue_norms = @cues.map { |cue| [cue["id"].to_s, normalize(cue["text"]), cue] }

      @items.each_with_object({}) do |item, memo|
        quote = normalize(item[:full_quote].presence || item[:quote].presence || item[:summary])
        next if quote.blank?

        matched = cue_norms.filter_map do |id, cue_text, _cue|
          next if cue_text.blank?
          next unless overlap?(quote, cue_text)

          id
        end

        memo[item[:id].to_s] = matched if matched.any?
      end
    end

    private

    def normalize(text)
      text.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
    end

    def overlap?(quote, cue_text)
      return true if quote.include?(cue_text) && cue_text.length >= MIN_FRAGMENT
      return true if cue_text.include?(quote) && quote.length >= MIN_FRAGMENT

      # Short cues (common in VTT): require the cue to appear as a token span in the quote.
      return true if cue_text.length >= 12 && quote.include?(cue_text)

      false
    end
  end
end
