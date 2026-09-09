# frozen_string_literal: true

module Positions
  # Structural Position Expectation Alignment Score — completeness of required
  # assignment outcomes + ability abilities. Persisted and refreshed daily /
  # on demand. PositionAbility rows do not affect this score.
  class ExpectationAlignmentScore
    POSITION_BLURBS = {
      strongly_misaligned:
        "We have work to do! Making expectations clear is the first step to creating an environment " \
        "where flow state powered excellence can thrive! This score means %{position} still lacks the " \
        "required assignment outcomes and ability milestones needed for a clear blueprint. Add outcomes " \
        "and at least two ability requirements on each required assignment.",
      misaligned:
        "This needs attention. Making expectations clear is the first step to creating an environment " \
        "where flow state powered excellence can thrive! This score means %{position}'s required " \
        "assignments are only partly set up—many are missing outcomes or enough ability milestones. " \
        "Close those gaps so people know what excellence looks like in this position.",
      slightly_misaligned:
        "We're below the line. Making expectations clear is the first step to creating an environment " \
        "where flow state powered excellence can thrive! This score suggests %{position} still has " \
        "required assignments without outcomes or with fewer than two ability milestones. Finish those " \
        "assignment blueprints so the position expectation stack is solid.",
      slightly_aligned:
        "On the right side of the line—barely. Making expectations clear is the first step to creating " \
        "an environment where flow state powered excellence can thrive! Most required assignments on " \
        "%{position} have outcomes and ability milestones, but a few still drag the score down. Bring " \
        "every required assignment up to two+ abilities with outcomes defined.",
      aligned:
        "Solid progress. Making expectations clear is the first step to creating an environment where" \
        " flow state powered excellence can thrive! %{position}'s required assignments mostly have " \
        "outcomes and two or more ability milestones. Keep polishing the remaining gaps so this becomes " \
        "Strongly Aligned.",
      strongly_aligned:
        "Congrats! Making expectations clear is the first step to creating an environment where flow " \
        "state powered excellence can thrive! This score means %{position}'s required assignments have " \
        "outcomes and the ability milestones needed for a clear expectation blueprint. Well done!"
    }.freeze

    SCORE_BANDS = AssignmentSurveys::ExpectationAlignmentScore::SCORE_BANDS.map do |band|
      band.merge(blurb: POSITION_BLURBS.fetch(band[:key]))
    end.freeze

    Cell = Struct.new(
      :assignment_id,
      :assignment_title,
      :outcomes_count,
      :abilities_count,
      :completeness_pct,
      :weight_points,
      :contribution,
      :blocker,
      keyword_init: true
    )

    Result = Struct.new(
      :calculated?,
      :calculated_at,
      :score,
      :show_card?,
      :can_see_score?,
      :can_refresh?,
      :required_assignments_count,
      :cells,
      keyword_init: true
    )

    def self.recalculate!(position:, reference_time: Time.current)
      new(position: position, organization: position.company, reference_time: reference_time).persist!
    end

    def self.for_viewer(position:, viewer:, organization:)
      new(position: position, viewer: viewer, organization: organization).present
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

    def self.assignment_completeness_pct(outcomes_count:, abilities_count:)
      return 0 if outcomes_count.to_i <= 0

      case abilities_count.to_i
      when 0 then 0
      when 1 then 50
      else 100
      end
    end

    def initialize(position:, organization:, viewer: nil, reference_time: Time.current)
      @position = position
      @organization = organization
      @viewer = viewer
      @reference_time = reference_time
    end

    def persist!
      payload = compute_payload
      record = PositionExpectationAlignmentScore.find_or_initialize_by(position_id: position.id)
      record.organization_id = organization.id
      record.score = payload[:score]
      record.cells = payload[:cells]
      record.required_assignments_count = payload[:required_assignments_count]
      record.calculated_at = reference_time
      record.save!
      record
    end

    def present
      cache = position.expectation_alignment_score_cache
      privileged = self.class.privileged_viewer?(viewer: viewer)
      calculated = cache.present?

      Result.new(
        calculated?: calculated,
        calculated_at: cache&.calculated_at,
        score: cache&.score,
        show_card?: true,
        can_see_score?: calculated,
        can_refresh?: privileged,
        required_assignments_count: cache&.required_assignments_count || 0,
        cells: deserialize_cells(cache&.cells)
      )
    end

    private

    attr_reader :position, :organization, :viewer, :reference_time

    def compute_payload
      rows = required_assignment_rows
      count = rows.size

      if count.zero?
        return {
          score: 0,
          cells: [],
          required_assignments_count: 0
        }
      end

      weight = (100.0 / count)
      cells = rows.map do |row|
        completeness = self.class.assignment_completeness_pct(
          outcomes_count: row[:outcomes_count],
          abilities_count: row[:abilities_count]
        )
        contribution = (weight * (completeness / 100.0)).round(2)
        blocker =
          if row[:outcomes_count] <= 0
            "missing_outcomes"
          elsif row[:abilities_count] <= 0
            "missing_abilities"
          elsif row[:abilities_count] == 1
            "partial_abilities"
          end

        {
          "assignment_id" => row[:assignment_id],
          "assignment_title" => row[:assignment_title],
          "outcomes_count" => row[:outcomes_count],
          "abilities_count" => row[:abilities_count],
          "completeness_pct" => completeness,
          "weight_points" => weight.round(2),
          "contribution" => contribution,
          "blocker" => blocker
        }
      end

      score = cells.sum { |cell| cell["contribution"] }.round(1)

      {
        score: score,
        cells: cells,
        required_assignments_count: count
      }
    end

    def required_assignment_rows
      position.position_assignments
              .required
              .includes(assignment: [:assignment_outcomes, :assignment_abilities])
              .ordered_by_max_energy_then_title
              .filter_map do |pa|
                assignment = pa.assignment
                next if assignment.blank?

                {
                  assignment_id: assignment.id,
                  assignment_title: assignment.title.to_s,
                  outcomes_count: assignment.assignment_outcomes.size,
                  abilities_count: assignment.assignment_abilities.size
                }
              end
    end

    def deserialize_cells(raw)
      Array(raw).map do |cell|
        hash = cell.respond_to?(:with_indifferent_access) ? cell.with_indifferent_access : cell
        Cell.new(
          assignment_id: hash[:assignment_id] || hash["assignment_id"],
          assignment_title: hash[:assignment_title] || hash["assignment_title"],
          outcomes_count: (hash[:outcomes_count] || hash["outcomes_count"]).to_i,
          abilities_count: (hash[:abilities_count] || hash["abilities_count"]).to_i,
          completeness_pct: (hash[:completeness_pct] || hash["completeness_pct"]).to_i,
          weight_points: (hash[:weight_points] || hash["weight_points"]).to_f,
          contribution: (hash[:contribution] || hash["contribution"]).to_f,
          blocker: hash[:blocker] || hash["blocker"]
        )
      end
    end
  end
end
