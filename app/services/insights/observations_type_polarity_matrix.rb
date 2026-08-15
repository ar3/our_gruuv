# frozen_string_literal: true

module Insights
  # Crosstab of observation_type × rating polarity for Observations insights.
  # Polarity ignores N/A ratings: only positive/negative ratings count.
  # Observations with no positive or negative ratings (including N/A-only) are "no_ratings".
  class ObservationsTypePolarityMatrix
    TYPE_KEYS = %w[generic kudos feedback quick_note].freeze
    TYPE_LABELS = {
      "generic" => "Generic",
      "kudos" => "Kudos",
      "feedback" => "Feedback",
      "quick_note" => "Quick note"
    }.freeze

    POLARITY_KEYS = %w[no_ratings all_positive all_negative mix].freeze
    POLARITY_LABELS = {
      "no_ratings" => "No ratings",
      "all_positive" => "All positive",
      "all_negative" => "All negative",
      "mix" => "Mix"
    }.freeze

    def self.call(observations)
      new(observations).call
    end

    def self.polarity_for(observation)
      ratings = observation.observation_ratings
      has_pos = ratings.any?(&:positive?)
      has_neg = ratings.any?(&:negative?)

      if !has_pos && !has_neg
        "no_ratings"
      elsif has_pos && !has_neg
        "all_positive"
      elsif has_neg && !has_pos
        "all_negative"
      else
        "mix"
      end
    end

    def initialize(observations)
      @observations = observations
    end

    def call
      counts = empty_counts
      @observations.each do |observation|
        type_key = normalize_type(observation.observation_type)
        polarity_key = self.class.polarity_for(observation)
        counts[type_key][polarity_key] += 1
      end

      total = counts.values.sum { |row| row.values.sum }
      type_labels = TYPE_KEYS.map { |k| TYPE_LABELS[k] }
      polarity_labels = POLARITY_KEYS.map { |k| POLARITY_LABELS[k] }

      {
        total: total,
        type_keys: TYPE_KEYS,
        type_labels: type_labels,
        polarity_keys: POLARITY_KEYS,
        polarity_labels: polarity_labels,
        counts: counts,
        heatmap: heatmap_payload(counts, total, type_labels, polarity_labels),
        stacked: stacked_payload(counts, total, type_labels)
      }
    end

    private

    def empty_counts
      TYPE_KEYS.index_with do
        POLARITY_KEYS.index_with { 0 }
      end
    end

    def normalize_type(observation_type)
      key = observation_type.to_s
      TYPE_KEYS.include?(key) ? key : "generic"
    end

    def pct(count, total)
      return 0.0 if total.zero?

      ((count.to_f / total) * 100).round(1)
    end

    def heatmap_payload(counts, total, type_labels, polarity_labels)
      data = []
      TYPE_KEYS.each_with_index do |type_key, y|
        POLARITY_KEYS.each_with_index do |polarity_key, x|
          value = counts[type_key][polarity_key]
          data << {
            x: x,
            y: y,
            value: value,
            pct: pct(value, total)
          }
        end
      end

      {
        x_categories: polarity_labels,
        y_categories: type_labels,
        data: data
      }
    end

    def stacked_payload(counts, total, type_labels)
      series = POLARITY_KEYS.map do |polarity_key|
        values = TYPE_KEYS.map { |type_key| counts[type_key][polarity_key] }
        {
          name: POLARITY_LABELS[polarity_key],
          data: values,
          pct_data: values.map { |v| pct(v, total) }
        }
      end

      {
        categories: type_labels,
        series: series
      }
    end
  end
end
