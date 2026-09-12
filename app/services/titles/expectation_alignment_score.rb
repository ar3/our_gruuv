# frozen_string_literal: true

module Titles
  # Title Expectation Alignment Score — path clarity (25%) + L1/L2/L3 Position EAS
  # (25% each). Missing unarchived position for a minor slot scores 0 for that quarter.
  class ExpectationAlignmentScore
    COMPONENT_WEIGHT = 25.0
    MINOR_SLOTS = [1, 2, 3].freeze

    TITLE_BLURBS = {
      strongly_misaligned:
        "We have work to do! Making expectations clear is the first step to creating an environment " \
        "where flow state powered excellence can thrive! This score means %{title} is missing path " \
        "clarity and/or L1–L3 position expectation setup. Fill all three position levels, strengthen " \
        "each position’s required assignments, and set after paths or mark the title end-cap.",
      misaligned:
        "This needs attention. Making expectations clear is the first step to creating an environment " \
        "where flow state powered excellence can thrive! This score means %{title} still has gaps in " \
        "path clarity or position-level expectation alignment. Close missing levels and thin Position " \
        "EAS scores so the title blueprint is trustworthy.",
      slightly_misaligned:
        "We're below the line. Making expectations clear is the first step to creating an environment " \
        "where flow state powered excellence can thrive! This score suggests %{title} is partly set " \
        "up—path clarity or one or more L1–L3 positions still drag the score down. Finish those pieces.",
      slightly_aligned:
        "On the right side of the line—barely. Making expectations clear is the first step to creating " \
        "an environment where flow state powered excellence can thrive! %{title} is mostly clear, but " \
        "path clarity or a weaker position level is holding the score back. Polish the remaining gaps.",
      aligned:
        "Solid progress. Making expectations clear is the first step to creating an environment where" \
        " flow state powered excellence can thrive! %{title} has strong path clarity and solid L1–L3 " \
        "Position EAS. Keep tightening the weakest level so this becomes Strongly Aligned.",
      strongly_aligned:
        "Congrats! Making expectations clear is the first step to creating an environment where flow " \
        "state powered excellence can thrive! This score means %{title} has path clarity (end-cap or " \
        "after paths) and strong expectation alignment across L1–L3. Well done!"
    }.freeze

    SCORE_BANDS = AssignmentSurveys::ExpectationAlignmentScore::SCORE_BANDS.map do |band|
      band.merge(blurb: TITLE_BLURBS.fetch(band[:key]))
    end.freeze

    Cell = Struct.new(
      :key,
      :label,
      :weight_points,
      :contribution,
      :path_clarity,
      :path_clarity_reason,
      :minor,
      :position_id,
      :position_name,
      :position_eas,
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
      :path_clarity,
      :cells,
      keyword_init: true
    )

    def self.recalculate!(title:, reference_time: Time.current, refresh_positions: true)
      new(
        title: title,
        organization: title.company,
        reference_time: reference_time,
        refresh_positions: refresh_positions
      ).persist!
    end

    def self.for_viewer(title:, viewer:, organization:)
      new(title: title, viewer: viewer, organization: organization).present
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

    def initialize(title:, organization:, viewer: nil, reference_time: Time.current, refresh_positions: false)
      @title = title
      @organization = organization
      @viewer = viewer
      @reference_time = reference_time
      @refresh_positions = refresh_positions
    end

    def persist!
      refresh_position_scores! if refresh_positions

      payload = compute_payload
      record = TitleExpectationAlignmentScore.find_or_initialize_by(title_id: title.id)
      record.organization_id = organization.id
      record.score = payload[:score]
      record.cells = payload[:cells]
      record.path_clarity = payload[:path_clarity]
      record.calculated_at = reference_time
      record.save!
      record
    end

    def present
      cache = title.expectation_alignment_score_cache
      privileged = self.class.privileged_viewer?(viewer: viewer)
      calculated = cache.present?

      Result.new(
        calculated?: calculated,
        calculated_at: cache&.calculated_at,
        score: cache&.score,
        show_card?: true,
        can_see_score?: calculated,
        can_refresh?: privileged,
        path_clarity: cache&.path_clarity || false,
        cells: deserialize_cells(cache&.cells)
      )
    end

    private

    attr_reader :title, :organization, :viewer, :reference_time, :refresh_positions

    def refresh_position_scores!
      title.positions.unarchived.includes(:position_level, :title).find_each do |position|
        Positions::ExpectationAlignmentScore.recalculate!(
          position: position,
          reference_time: reference_time
        )
      end
    end

    def compute_payload
      cells = []
      path_cell = path_clarity_cell
      cells << path_cell

      positions_by_minor = positions_by_eligibility_minor
      MINOR_SLOTS.each do |minor|
        cells << level_cell(minor: minor, position: positions_by_minor[minor])
      end

      score = cells.sum { |cell| cell["contribution"].to_f }.round(1)

      {
        score: score,
        cells: cells,
        path_clarity: path_cell["path_clarity"]
      }
    end

    def path_clarity_cell
      clear = title.end_cap? || title.outbound_title_paths.exists?
      reason =
        if title.end_cap?
          "end_cap"
        elsif title.outbound_title_paths.exists?
          "has_outbound"
        else
          "missing"
        end

      {
        "key" => "path_clarity",
        "label" => "Path clarity",
        "weight_points" => COMPONENT_WEIGHT,
        "contribution" => clear ? COMPONENT_WEIGHT : 0.0,
        "path_clarity" => clear,
        "path_clarity_reason" => reason,
        "minor" => nil,
        "position_id" => nil,
        "position_name" => nil,
        "position_eas" => nil,
        "blocker" => clear ? nil : "missing_path_clarity"
      }
    end

    def level_cell(minor:, position:)
      label = "L#{minor} position"
      if position.blank?
        return {
          "key" => "level_#{minor}",
          "label" => label,
          "weight_points" => COMPONENT_WEIGHT,
          "contribution" => 0.0,
          "path_clarity" => nil,
          "path_clarity_reason" => nil,
          "minor" => minor,
          "position_id" => nil,
          "position_name" => nil,
          "position_eas" => nil,
          "blocker" => "missing_position"
        }
      end

      eas = position.expectation_alignment_score_cache&.score&.to_f || 0.0
      contribution = ((eas / 100.0) * COMPONENT_WEIGHT).round(2)

      {
        "key" => "level_#{minor}",
        "label" => label,
        "weight_points" => COMPONENT_WEIGHT,
        "contribution" => contribution,
        "path_clarity" => nil,
        "path_clarity_reason" => nil,
        "minor" => minor,
        "position_id" => position.id,
        "position_name" => position.display_name,
        "position_eas" => eas.round(1),
        "blocker" => eas <= 0 ? "zero_position_eas" : nil
      }
    end

    def positions_by_eligibility_minor
      title.positions
           .unarchived
           .includes(:position_level, :expectation_alignment_score_cache)
           .each_with_object({}) do |position, hash|
             minor = position.position_level.eligibility_minor_slot
             hash[minor] ||= position
           rescue ArgumentError
             next
           end
    end

    def deserialize_cells(raw)
      Array(raw).map do |cell|
        hash = cell.respond_to?(:with_indifferent_access) ? cell.with_indifferent_access : cell
        Cell.new(
          key: hash[:key] || hash["key"],
          label: hash[:label] || hash["label"],
          weight_points: (hash[:weight_points] || hash["weight_points"]).to_f,
          contribution: (hash[:contribution] || hash["contribution"]).to_f,
          path_clarity: hash[:path_clarity].nil? && hash["path_clarity"].nil? ? nil : ActiveModel::Type::Boolean.new.cast(hash[:path_clarity] || hash["path_clarity"]),
          path_clarity_reason: hash[:path_clarity_reason] || hash["path_clarity_reason"],
          minor: (hash[:minor] || hash["minor"])&.to_i&.nonzero?,
          position_id: hash[:position_id] || hash["position_id"],
          position_name: hash[:position_name] || hash["position_name"],
          position_eas: (eas = hash[:position_eas] || hash["position_eas"]).nil? ? nil : eas.to_f,
          blocker: hash[:blocker] || hash["blocker"]
        )
      end
    end
  end
end
