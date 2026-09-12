# frozen_string_literal: true

module Positions
  # Positions to surface first in the Grow-by next-goal dropdown.
  # Within-title: all higher levels on the same title.
  # Outbound paths: all unarchived positions on destination titles (any path type).
  class SuggestedNextForGrowBy
    Result = Struct.new(
      :same_title_positions,
      :path_positions,
      :empty_note,
      keyword_init: true
    ) do
      def positions
        (same_title_positions + path_positions).uniq(&:id)
      end

      def any?
        same_title_positions.any? || path_positions.any?
      end
    end

    def self.call(current_position:)
      new(current_position: current_position).call
    end

    def initialize(current_position:)
      @current_position = current_position
    end

    def call
      unless current_position
        return Result.new(
          same_title_positions: [],
          path_positions: [],
          empty_note: "No current position — set employment before the career map can suggest a next step. You can still pick any position below once positions exist."
        )
      end

      higher = higher_positions_on_same_title
      via_paths = positions_on_outbound_path_titles

      if higher.empty? && via_paths.empty?
        return Result.new(
          same_title_positions: [],
          path_positions: [],
          empty_note: empty_note_for(higher: higher, via_paths: via_paths)
        )
      end

      Result.new(
        same_title_positions: higher,
        path_positions: via_paths,
        empty_note: nil
      )
    end

    private

    attr_reader :current_position

    def title
      @title ||= current_position.title
    end

    def current_level_tuple
      @current_level_tuple ||= level_tuple(current_position.position_level&.level)
    end

    def higher_positions_on_same_title
      title.positions
           .unarchived
           .includes(:title, :position_level)
           .reject { |position| position.id == current_position.id }
           .select { |position| level_higher?(level_tuple(position.position_level&.level), current_level_tuple) }
           .sort_by { |position| level_tuple(position.position_level&.level) }
    end

    def positions_on_outbound_path_titles
      destination_ids = title.outbound_title_paths.map(&:to_title_id).uniq
      return [] if destination_ids.empty?

      Position.unarchived
              .joins(:title, :position_level)
              .where(titles: { id: destination_ids })
              .includes(:title, :position_level)
              .ordered
              .to_a
    end

    def level_tuple(level_str)
      major, minor = level_str.to_s.split(".", 2).map(&:to_i)
      [major.to_i, minor.to_i]
    end

    def level_higher?(candidate, baseline)
      (candidate <=> baseline) == 1
    end

    def empty_note_for(higher:, via_paths:)
      if title.end_cap? && higher.empty?
        "This title is an end-cap and there is no higher level on it, so there is no suggested next position from the career map. You can still pick any position below."
      elsif higher.empty? && title.outbound_title_paths.none?
        "No suggested next positions yet — add a higher level on this title or an after title path, or pick any position below."
      else
        "No suggested next positions from the career map right now. You can still pick any position below."
      end
    end
  end
end
