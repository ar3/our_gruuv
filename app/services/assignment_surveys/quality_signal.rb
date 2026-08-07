# frozen_string_literal: true

module AssignmentSurveys
  # Opinionated OG read of an assignment-survey average for scan + popover.
  class QualitySignal
    DISSENT_RATINGS = [ 1, 2, 3 ].freeze
    SMALL_SAMPLE_THRESHOLD = 3
    POSITIVE_KEYS = %i[healthy incredible].freeze

    BANDS = [
      {
        key: :critical,
        label: "Critical",
        icon: "bi-x-octagon-fill",
        territory: "strongly disagree",
        range: "below 2.0",
        matches: ->(average) { average < 2.0 }
      },
      {
        key: :poor,
        label: "Poor",
        icon: "bi-emoji-frown-fill",
        territory: "disagree",
        range: "2.0 to less than 3.0",
        matches: ->(average) { average >= 2.0 && average < 3.0 }
      },
      {
        key: :concerning,
        label: "Concerning",
        icon: "bi-exclamation-triangle-fill",
        territory: "somewhat disagree",
        range: "3.0 to less than 4.0",
        matches: ->(average) { average >= 3.0 && average < 4.0 }
      },
      {
        key: :strained,
        label: "Strained",
        icon: "bi-exclamation-circle-fill",
        territory: "somewhat agree",
        range: "4.0 to less than 5.0",
        matches: ->(average) { average >= 4.0 && average < 5.0 }
      },
      {
        key: :healthy,
        label: "Healthy",
        icon: "bi-check-circle-fill",
        territory: "agree",
        range: "5.0 to less than 5.5",
        matches: ->(average) { average >= 5.0 && average < 5.5 }
      },
      {
        key: :incredible,
        label: "Incredible",
        icon: "bi-stars",
        territory: "strongly agree",
        range: "5.5 and above",
        matches: ->(average) { average >= 5.5 }
      }
    ].freeze

    Result = Data.define(
      :key,
      :label,
      :icon,
      :territory,
      :range_description,
      :average,
      :total,
      :dissent_count,
      :small_sample?,
      :show_caution?
    )

    def self.from_distribution(distribution)
      return nil if distribution.blank?

      new(
        average: distribution[:average],
        counts: distribution[:counts] || {},
        total: distribution[:total]
      ).call
    end

    def self.band_for(average)
      return nil if average.nil?

      BANDS.find { |band| band[:matches].call(average.to_f) }
    end

    def initialize(average:, counts:, total: nil)
      @average = average
      @counts = counts || {}
      @total = total.nil? ? @counts.values.sum : total.to_i
    end

    def call
      band = self.class.band_for(@average)
      return nil unless band

      dissent_count = DISSENT_RATINGS.sum { |rating| @counts.fetch(rating, 0).to_i }
      positive = POSITIVE_KEYS.include?(band[:key])

      Result.new(
        key: band[:key],
        label: band[:label],
        icon: band[:icon],
        territory: band[:territory],
        range_description: band[:range],
        average: @average,
        total: @total,
        dissent_count: dissent_count,
        small_sample?: @total.positive? && @total < SMALL_SAMPLE_THRESHOLD,
        show_caution?: positive && dissent_count.positive?
      )
    end
  end
end
