# frozen_string_literal: true

module Aspirations
  # Values Expectation Alignment Score — check-in emp/mgr agreement only
  # (no survey U/P/R). Persisted and refreshed daily / on demand.
  class ExpectationAlignmentScore
    PUBLIC_EMPLOYEE_THRESHOLD = 2

    AGE_BANDS = AssignmentSurveys::ExpectationAlignmentScore::AGE_BANDS

    CELL_WEIGHTS = {
      fresh: 8,
      aging: 4,
      old: 2
    }.freeze

    # Same display bands as Assignments; Values-specific blurbs (`%{name}`).
    SCORE_BANDS = [
      {
        key: :critical,
        label: "Worst",
        icon: "bi-x-octagon-fill",
        min: 0,
        max_exclusive: 30,
        blurb:
          "We have work to do! Making expectations clear is the first step to creating an environment " \
          "where flow state powered excellence can thrive! This score means that when people check in on " \
          "%{name}, employees and managers often arrive at DIFFERENT conclusions—a strong signal that " \
          "what “living this value” looks like is MISALIGNED. Clarify what this Value means in practice " \
          "and talk through recent check-ins until ratings start to converge."
      },
      {
        key: :poor,
        label: "Bad",
        icon: "bi-emoji-frown-fill",
        min: 30,
        max_exclusive: 50,
        blurb:
          "This needs attention. Making expectations clear is the first step to creating an environment " \
          "where flow state powered excellence can thrive! This score means check-ins on %{name} " \
          "frequently end with the employee and manager in different places. Tighten how this Value is " \
          "described and coached so “meeting expectations” means the same thing to both sides."
      },
      {
        key: :concerning,
        label: "Slightly Bad",
        icon: "bi-exclamation-triangle-fill",
        min: 50,
        max_exclusive: 65,
        blurb:
          "We're below the line. Making expectations clear is the first step to creating an environment " \
          "where flow state powered excellence can thrive! This score suggests check-ins on %{name} " \
          "still disagree too often. Surface recent mismatches and align on concrete examples of what " \
          "this Value looks like day to day."
      },
      {
        key: :strained,
        label: "Slightly Good",
        icon: "bi-exclamation-circle-fill",
        min: 65,
        max_exclusive: 80,
        blurb:
          "On the right side of the line—barely. Making expectations clear is the first step to creating " \
          "an environment where flow state powered excellence can thrive! Check-ins on %{name} agree more " \
          "often than not, but friction remains. Keep closing employee/manager rating gaps so “slightly " \
          "good” becomes clearly good."
      },
      {
        key: :healthy,
        label: "Good",
        icon: "bi-check-circle-fill",
        min: 80,
        max_exclusive: 95,
        blurb:
          "Solid progress. Making expectations clear is the first step to creating an environment where " \
          "flow state powered excellence can thrive! This score means employees and managers usually " \
          "arrive at the same conclusion when checking in on %{name}. Keep nurturing that shared " \
          "picture—small clarifications can push this from good to great."
      },
      {
        key: :incredible,
        label: "Great",
        icon: "bi-stars",
        min: 95,
        max_exclusive: nil,
        blurb:
          "Congrats! Making expectations clear is the first step to creating an environment where flow " \
          "state powered excellence can thrive! This score means that when check-ins are done on " \
          "%{name}, the employee and manager often arrive at the same conclusion—the best indication " \
          "of expectation alignment for this Value. Well done!"
      }
    ].freeze

    Cell = Struct.new(
      :band,
      :signal,
      :label,
      :score_0_100,
      :base_weight,
      :effective_weight,
      :sample_size,
      :included?,
      keyword_init: true
    )

    Result = Struct.new(
      :calculated?,
      :calculated_at,
      :score,
      :show_card?,
      :can_see_score?,
      :can_refresh?,
      :privileged_viewer?,
      :threshold_met?,
      :check_in_teammate_count,
      :cells,
      keyword_init: true
    )

    def self.recalculate!(aspiration:, reference_time: Time.current)
      new(aspiration: aspiration, organization: aspiration.company, reference_time: reference_time).persist!
    end

    def self.for_viewer(aspiration:, viewer:, organization:)
      new(aspiration: aspiration, viewer: viewer, organization: organization).present
    end

    def self.band_for_score(score)
      return nil if score.nil?

      value = score.to_f
      SCORE_BANDS.find do |band|
        min = band[:min]
        max = band[:max_exclusive]
        next false if value < min
        next true if max.nil?

        value < max
      end
    end

    def self.callout_text_align(score)
      AssignmentSurveys::ExpectationAlignmentScore.callout_text_align(score)
    end

    def self.privileged_viewer?(viewer:)
      return false if viewer.blank?

      viewer.can_manage_maap?
    end

    def initialize(aspiration:, organization:, viewer: nil, reference_time: Time.current)
      @aspiration = aspiration
      @organization = organization
      @viewer = viewer
      @reference_time = reference_time
    end

    def persist!
      payload = compute_payload
      record = AspirationExpectationAlignmentScore.find_or_initialize_by(aspiration_id: aspiration.id)
      record.organization_id = organization.id
      record.score = payload[:score]
      record.cells = payload[:cells]
      record.check_in_teammate_count = payload[:check_in_teammate_count]
      record.calculated_at = reference_time
      record.save!
      record
    end

    def present
      privileged = self.class.privileged_viewer?(viewer: viewer)
      record = AspirationExpectationAlignmentScore.find_by(aspiration_id: aspiration.id)

      if record.nil?
        return Result.new(
          calculated?: false,
          calculated_at: nil,
          score: nil,
          show_card?: privileged,
          can_see_score?: false,
          can_refresh?: privileged,
          privileged_viewer?: privileged,
          threshold_met?: false,
          check_in_teammate_count: 0,
          cells: []
        )
      end

      threshold_met = record.threshold_met?
      can_see_score = privileged || threshold_met

      Result.new(
        calculated?: true,
        calculated_at: record.calculated_at,
        score: record.score&.to_f,
        show_card?: true,
        can_see_score?: can_see_score,
        can_refresh?: can_see_score,
        privileged_viewer?: privileged,
        threshold_met?: threshold_met,
        check_in_teammate_count: record.check_in_teammate_count,
        cells: deserialize_cells(record.cells)
      )
    end

    private

    attr_reader :aspiration, :viewer, :organization, :reference_time

    def compute_payload
      alignment_by_band = alignment_scores_by_band

      cells = CELL_WEIGHTS.map do |band, base_weight|
        payload = alignment_by_band[band]
        score = payload[:score]
        included = score.present?
        {
          "band" => band.to_s,
          "signal" => "alignment",
          "label" => AGE_BANDS.fetch(band).fetch(:label),
          "score_0_100" => score,
          "base_weight" => base_weight,
          "effective_weight" => included ? base_weight : 0,
          "sample_size" => payload[:sample_size],
          "included" => included
        }
      end

      included_cells = cells.select { |cell| cell["included"] }
      total_weight = included_cells.sum { |cell| cell["effective_weight"] }
      score =
        if total_weight.positive?
          weighted = included_cells.sum { |cell| cell["score_0_100"] * cell["effective_weight"] }
          (weighted / total_weight.to_f).round(1)
        end

      {
        score: score,
        cells: cells,
        check_in_teammate_count: qualifying_check_ins.map(&:teammate_id).uniq.size
      }
    end

    def deserialize_cells(raw_cells)
      Array(raw_cells).map do |cell|
        Cell.new(
          band: cell["band"]&.to_sym,
          signal: cell["signal"]&.to_sym,
          label: cell["label"],
          score_0_100: cell["score_0_100"],
          base_weight: cell["base_weight"],
          effective_weight: cell["effective_weight"],
          sample_size: cell["sample_size"],
          included?: cell["included"]
        )
      end
    end

    def qualifying_check_ins
      @qualifying_check_ins ||= AspirationCheckIn
        .closed
        .where(aspiration_id: aspiration.id)
        .where.not(employee_rating: nil)
        .where.not(manager_rating: nil)
        .to_a
    end

    def alignment_scores_by_band
      buckets = { fresh: [], aging: [], old: [] }
      qualifying_check_ins.each do |check_in|
        band = age_band_for(check_in.official_check_in_completed_at)
        next unless band

        buckets[band] << (check_in.employee_rating == check_in.manager_rating)
      end

      buckets.transform_values do |agreements|
        if agreements.empty?
          { score: nil, sample_size: 0 }
        else
          ratio = agreements.count(true).to_f / agreements.size
          { score: (ratio * 100.0).round(1), sample_size: agreements.size }
        end
      end
    end

    def age_band_for(timestamp)
      return nil if timestamp.blank?

      days = (reference_time.to_date - timestamp.to_date).to_i
      return nil if days.negative?

      AGE_BANDS.each do |band, bounds|
        min = bounds[:min_inclusive]
        max = bounds[:max_exclusive]
        next if min && days < min
        next if max && days >= max

        return band
      end
      nil
    end
  end
end
