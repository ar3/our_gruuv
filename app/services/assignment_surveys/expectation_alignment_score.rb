# frozen_string_literal: true

module AssignmentSurveys
  # Results-based Expectation Alignment Score for a single assignment.
  # Computation is persisted on AssignmentExpectationAlignmentScore and refreshed
  # daily / on demand — not on every assignment show.
  class ExpectationAlignmentScore
    PUBLIC_EMPLOYEE_THRESHOLD = 2

    AGE_BANDS = {
      fresh: { label: "Fresh (<90 days)", max_exclusive: 90 },
      aging: { label: "Aging (90–179 days)", min_inclusive: 90, max_exclusive: 180 },
      old: { label: "Old (180+ days)", min_inclusive: 180 }
    }.freeze

    # Relative weights: newer > older; agreement column ×2 vs U/P/R ×1.
    CELL_WEIGHTS = {
      [ :fresh, :alignment ] => 8,
      [ :fresh, :upr ] => 4,
      [ :aging, :alignment ] => 4,
      [ :aging, :upr ] => 2,
      [ :old, :alignment ] => 2,
      [ :old, :upr ] => 1
    }.freeze

    LIKERT_ATTRIBUTES = %i[understandable_rating possible_rating relevant_rating].freeze

    # 0–100 display bands. Keys/icons align with AssignmentSurveys::QualitySignal
    # so we reuse the survey quality colors. `%{assignment}` is replaced with the title.
    SCORE_BANDS = [
      {
        key: :critical,
        label: "Worst",
        icon: "bi-x-octagon-fill",
        min: 0,
        max_exclusive: 30,
        blurb:
          "We have work to do! Making expectations clear is the first step to creating an environment " \
          "where flow state powered excellence can thrive! This score means that taking on %{assignment} " \
          "is NOT understandable, an appropriate challenge, relevant, and/or when check-ins are done " \
          "often the employee and manager arrive at DIFFERENT conclusions (which is the best indication " \
          "of a MISALIGNMENT of expectations). Review the outcomes, and consider doing an OG Consultation " \
          "to help make this Assignment more clear!"
      },
      {
        key: :poor,
        label: "Bad",
        icon: "bi-emoji-frown-fill",
        min: 30,
        max_exclusive: 50,
        blurb:
          "This needs attention. Making expectations clear is the first step to creating an environment " \
          "where flow state powered excellence can thrive! This score means that taking on %{assignment} " \
          "is often hard to understand, poorly calibrated as a challenge, weakly relevant, and/or " \
          "check-ins frequently end with the employee and manager in different places—a strong signal " \
          "of expectation misalignment. Tighten the outcomes and required activities, and consider an " \
          "OG Consultation before the gap gets worse."
      },
      {
        key: :concerning,
        label: "Slightly Bad",
        icon: "bi-exclamation-triangle-fill",
        min: 50,
        max_exclusive: 65,
        blurb:
          "We're below the line. Making expectations clear is the first step to creating an environment " \
          "where flow state powered excellence can thrive! This score suggests that taking on %{assignment} " \
          "still leaves too much ambiguity—whether in understandability, challenge level, relevance, or " \
          "how often employee and manager check-in ratings disagree. Address the weakest outcomes now so " \
          "this Assignment doesn't keep generating confusion."
      },
      {
        key: :strained,
        label: "Slightly Good",
        icon: "bi-exclamation-circle-fill",
        min: 65,
        max_exclusive: 80,
        blurb:
          "On the right side of the line—barely. Making expectations clear is the first step to creating " \
          "an environment where flow state powered excellence can thrive! This score means taking on " \
          "%{assignment} is starting to land as understandable, appropriately challenging, and relevant, " \
          "with check-ins more often aligned than not—but there's still friction. Polish the outcomes and " \
          "keep closing employee/manager rating gaps so “slightly good” becomes clearly good."
      },
      {
        key: :healthy,
        label: "Good",
        icon: "bi-check-circle-fill",
        min: 80,
        max_exclusive: 95,
        blurb:
          "Solid progress. Making expectations clear is the first step to creating an environment where " \
          "flow state powered excellence can thrive! This score means that taking on %{assignment} is " \
          "generally understandable, an appropriate challenge, and relevant, and employee and manager " \
          "check-ins usually arrive at the same conclusion. Keep nurturing that alignment—small " \
          "refinements to outcomes can push this from good to great."
      },
      {
        key: :incredible,
        label: "Great",
        icon: "bi-stars",
        min: 95,
        max_exclusive: nil,
        blurb:
          "Congrats! Making expectations clear is the first step to creating an environment where flow " \
          "state powered excellence can thrive! This score means that taking on %{assignment} is " \
          "understandable, an appropriate challenge, relevant, and when check-ins are done often the " \
          "employee and manager arrive at the same conclusion (which is the best indication of " \
          "expectation alignment). Well done!"
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
      :survey_respondent_count,
      :cells,
      keyword_init: true
    )

    def self.recalculate!(assignment:, reference_time: Time.current)
      new(assignment: assignment, organization: assignment.company, reference_time: reference_time).persist!
    end

    def self.for_viewer(assignment:, viewer:, organization:)
      new(assignment: assignment, viewer: viewer, organization: organization).present
    end

    def self.likert_to_0_100(average)
      return nil if average.nil?

      (((average - 1.0) / 5.0) * 100.0).round(1)
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

    # Full-width callout alignment tracks the marker: left near 0, center mid, right near 100.
    def self.callout_text_align(score)
      return "start" if score.nil?

      pct = score.to_f.clamp(0, 100)
      return "start" if pct < (100.0 / 3.0)
      return "end" if pct > (200.0 / 3.0)

      "center"
    end

    def self.privileged_viewer?(assignment:, viewer:)
      return false if viewer.blank?

      viewer.can_manage_maap? || assignment.maintained_by?(viewer)
    end

    def initialize(assignment:, organization:, viewer: nil, reference_time: Time.current)
      @assignment = assignment
      @organization = organization
      @viewer = viewer
      @reference_time = reference_time
    end

    def persist!
      payload = compute_payload
      record = AssignmentExpectationAlignmentScore.find_or_initialize_by(assignment_id: assignment.id)
      record.organization_id = organization.id
      record.score = payload[:score]
      record.cells = payload[:cells]
      record.check_in_teammate_count = payload[:check_in_teammate_count]
      record.survey_respondent_count = payload[:survey_respondent_count]
      record.calculated_at = reference_time
      record.save!
      record
    end

    def present
      privileged = self.class.privileged_viewer?(assignment: assignment, viewer: viewer)
      record = AssignmentExpectationAlignmentScore.find_by(assignment_id: assignment.id)

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
          survey_respondent_count: 0,
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
        survey_respondent_count: record.survey_respondent_count,
        cells: deserialize_cells(record.cells)
      )
    end

    private

    attr_reader :assignment, :viewer, :organization, :reference_time

    def compute_payload
      upr_by_band = upr_scores_by_band
      alignment_by_band = alignment_scores_by_band

      cells = CELL_WEIGHTS.map do |(band, signal), base_weight|
        payload = signal == :upr ? upr_by_band[band] : alignment_by_band[band]
        score = payload[:score]
        included = score.present?
        {
          "band" => band.to_s,
          "signal" => signal.to_s,
          "label" => cell_label(band, signal),
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
        check_in_teammate_count: qualifying_check_ins.map(&:teammate_id).uniq.size,
        survey_respondent_count: likert_responses.map(&:teammate_id).uniq.size
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

    def cell_label(band, signal)
      band_label = AGE_BANDS.fetch(band).fetch(:label)
      signal_label = signal == :upr ? "U/P/R feedback" : "Emp/mgr agreement"
      "#{band_label} · #{signal_label}"
    end

    def likert_responses
      @likert_responses ||= AssignmentSurveyResponse
        .submitted
        .where(assignment_id: assignment.id, organization_id: organization.id)
        .where(
          "understandable_rating IS NOT NULL OR possible_rating IS NOT NULL OR relevant_rating IS NOT NULL"
        )
        .to_a
    end

    def qualifying_check_ins
      @qualifying_check_ins ||= AssignmentCheckIn
        .closed
        .where(assignment_id: assignment.id)
        .where.not(employee_rating: nil)
        .where.not(manager_rating: nil)
        .to_a
    end

    def upr_scores_by_band
      buckets = empty_band_buckets
      likert_responses.each do |response|
        band = age_band_for(response.submitted_at)
        next unless band

        values = LIKERT_ATTRIBUTES.filter_map { |attr| response.public_send(attr) }
        next if values.empty?

        buckets[band].concat(values)
      end

      buckets.transform_values do |values|
        if values.empty?
          { score: nil, sample_size: 0 }
        else
          average = values.sum.to_f / values.size
          { score: self.class.likert_to_0_100(average), sample_size: values.size }
        end
      end
    end

    def alignment_scores_by_band
      buckets = empty_band_buckets
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

    def empty_band_buckets
      { fresh: [], aging: [], old: [] }
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
