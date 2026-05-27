# frozen_string_literal: true

module Insights
  # Shared rating-ratio bands and kudos-mix classification for Insights: Observations
  # and Observations Health (per-employee cache in later phases).
  class ObservationsRatingHealth
    KUDOS_CONSTRUCTIVE_HEALTHY_RATIO_LABEL = "5:1"
    SOLID_EXCEPTIONAL_HEALTHY_RATIO_LABEL = "3:1"
    MISALIGNED_CONCERNING_HEALTHY_RATIO_LABEL = "3:1"

    class << self
      def org_rating_health_ratio_rows(counts_by_rating)
        counts = rating_counts_from_grouped(counts_by_rating)
        kudos = counts[:strongly_agree] + counts[:agree]
        constructive = counts[:disagree] + counts[:strongly_disagree]

        [
          {
            name: "Kudos : Constructive",
            healthy_ratio: KUDOS_CONSTRUCTIVE_HEALTHY_RATIO_LABEL,
            display_ratio: rounded_ratio_display(kudos, constructive),
            popover_line_1: "Exceptional or Solid Ratings Total: #{kudos}",
            popover_line_2: "Misaligned or Concerning Ratings Total: #{constructive}",
            kudos_constructive_band: kudos_constructive_ratio_band(kudos, constructive)
          },
          {
            name: "Solid : Exceptional",
            healthy_ratio: SOLID_EXCEPTIONAL_HEALTHY_RATIO_LABEL,
            display_ratio: rounded_ratio_display(counts[:agree], counts[:strongly_agree]),
            popover_line_1: "Solid Ratings Total: #{counts[:agree]}",
            popover_line_2: "Exceptional Ratings Total: #{counts[:strongly_agree]}",
            solid_exceptional_band: two_tier_ratio_band(counts[:agree], counts[:strongly_agree])
          },
          {
            name: "Misaligned : Concerning",
            healthy_ratio: MISALIGNED_CONCERNING_HEALTHY_RATIO_LABEL,
            display_ratio: rounded_ratio_display(counts[:disagree], counts[:strongly_disagree]),
            popover_line_1: "Misaligned Ratings Total: #{counts[:disagree]}",
            popover_line_2: "Concerning Ratings Total: #{counts[:strongly_disagree]}",
            misaligned_concerning_band: two_tier_ratio_band(counts[:disagree], counts[:strongly_disagree])
          }
        ]
      end

      def rating_counts_from_grouped(counts_by_rating)
        {
          strongly_agree: counts_by_rating["strongly_agree"].to_i,
          agree: counts_by_rating["agree"].to_i,
          disagree: counts_by_rating["disagree"].to_i,
          strongly_disagree: counts_by_rating["strongly_disagree"].to_i
        }
      end

      def rating_counts_from_observations(observations)
        counts = { strongly_agree: 0, agree: 0, disagree: 0, strongly_disagree: 0 }
        observations.each do |observation|
          observation.observation_ratings.each do |rating|
            key = rating.rating.to_s
            counts[key.to_sym] += 1 if counts.key?(key.to_sym)
          end
        end
        counts
      end

      # Per published OGO (authored): kudos if any positive rating and no negative; otherwise constructive.
      def kudos_mix_side(observation)
        ratings = observation.observation_ratings
        has_positive = ratings.any?(&:positive?)
        has_negative = ratings.any?(&:negative?)
        return :kudos if has_positive && !has_negative

        :constructive
      end

      def kudos_constructive_counts_from_observations(observations)
        observations.each_with_object({ kudos: 0, constructive: 0 }) do |observation, tallies|
          side = kudos_mix_side(observation)
          tallies[side] += 1
        end
      end

      def kudos_constructive_band_for_observations(observations)
        tallies = kudos_constructive_counts_from_observations(observations)
        kudos_constructive_ratio_band(tallies[:kudos], tallies[:constructive])
      end

      # Less extreme (Solid + Misaligned) vs most extreme (Exceptional + Concerning).
      def combined_rating_intensity_band(counts)
        less_extreme = counts[:agree] + counts[:disagree]
        most_extreme = counts[:strongly_agree] + counts[:strongly_disagree]
        two_tier_ratio_band(less_extreme, most_extreme)
      end

      def combined_rating_intensity_band_for_observations(observations)
        combined_rating_intensity_band(rating_counts_from_observations(observations))
      end

      # Rounded ratio for display: e.g. 3:1 when left/right ≈ 3; whole numbers only.
      def rounded_ratio_display(left, right)
        l = left.to_i
        r = right.to_i
        return "0:0" if l.zero? && r.zero?
        return "#{l}:0" if r.zero?
        return "0:#{r}" if l.zero?

        x = (l.to_f / r).round
        "#{x}:1"
      end

      # Float kudos per constructive for banding (>7, 3..7, <3); :no_data if neither side has ratings.
      def kudos_constructive_ratio_band(kudos, constructive)
        k = kudos.to_i
        c = constructive.to_i
        return :no_data if k.zero? && c.zero?
        return :above_seven if c.zero? && k.positive?

        r = k.to_f / c
        return :above_seven if r > 7
        return :healthy if r >= 3

        :below_three
      end

      # For Solid:Exceptional, Misaligned:Concerning, and combined intensity — left:right where healthy ~3:1.
      # > 5:1 → “too rare” on the right bucket; < 1:1 → calibration concern.
      def two_tier_ratio_band(left, right)
        l = left.to_i
        r = right.to_i
        return :no_data if l.zero? && r.zero?
        return :above_five if r.zero? && l.positive?
        return :below_one if l.zero? && r.positive?

        ratio = l.to_f / r
        return :above_five if ratio > 5
        return :below_one if ratio < 1

        :healthy
      end
    end
  end
end
