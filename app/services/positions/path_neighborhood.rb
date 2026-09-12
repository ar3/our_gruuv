# frozen_string_literal: true

module Positions
  # Before/after neighbors for the position show "Position pathing" section.
  # Within-title: immediate previous / next level.
  # At the title exit (minor 3, or no higher level when already at minor 3):
  # outbound TitlePaths → earliest unarchived position on each destination title.
  class PathNeighborhood
    Neighbor = Struct.new(:position, :path_type_label, :source, keyword_init: true)

    Result = Struct.new(
      :positions_before,
      :positions_after,
      :after_state,
      :title,
      :entry_level,
      keyword_init: true
    ) do
      def end_cap?
        after_state == :end_cap
      end

      def undefined_after?
        after_state == :undefined
      end

      def missing_next_level?
        after_state == :missing_next_level
      end

      def entry_level?
        entry_level
      end
    end

    def self.call(position:)
      new(position: position).call
    end

    def initialize(position:)
      @position = position
    end

    def call
      Result.new(
        positions_before: build_before,
        positions_after: build_after_neighbors,
        after_state: @after_state,
        title: title,
        entry_level: minor_slot == 1
      )
    end

    private

    attr_reader :position

    def title
      @title ||= position.title
    end

    def same_title_positions
      @same_title_positions ||= title.positions
                                     .unarchived
                                     .includes(:title, :position_level)
                                     .to_a
                                     .sort_by { |p| level_tuple(p) }
    end

    def current_tuple
      @current_tuple ||= level_tuple(position)
    end

    def minor_slot
      return @minor_slot if defined?(@minor_slot)

      @minor_slot = begin
        position.position_level&.eligibility_minor_slot
      rescue ArgumentError
        nil
      end
    end

    def level_tuple(pos)
      level_str = pos.position_level&.level
      major, minor = level_str.to_s.split(".", 2).map(&:to_i)
      [major.to_i, minor.to_i]
    end

    def immediate_previous_same_title
      same_title_positions
        .reject { |p| p.id == position.id }
        .select { |p| (level_tuple(p) <=> current_tuple) == -1 }
        .max_by { |p| level_tuple(p) }
    end

    def immediate_next_same_title
      same_title_positions
        .reject { |p| p.id == position.id }
        .select { |p| (level_tuple(p) <=> current_tuple) == 1 }
        .min_by { |p| level_tuple(p) }
    end

    def build_before
      if minor_slot == 1
        latest_positions_from_inbound_titles
      else
        prev = immediate_previous_same_title
        return [] unless prev

        [Neighbor.new(position: prev, path_type_label: nil, source: :same_title)]
      end
    end

    def latest_positions_from_inbound_titles
      title.inbound_title_paths.includes(from_title: { positions: :position_level }).filter_map do |path|
        latest = path.from_title.positions.unarchived.max_by { |p| level_tuple(p) }
        next unless latest

        Neighbor.new(
          position: latest,
          path_type_label: path.path_type_label,
          source: :inbound_path
        )
      end
    end

    def build_after_neighbors
      if within_title_after_stage?
        next_pos = immediate_next_same_title
        if next_pos
          @after_state = :within_title
          return [Neighbor.new(position: next_pos, path_type_label: nil, source: :same_title)]
        end

        @after_state = :missing_next_level
        return []
      end

      if title.end_cap?
        @after_state = :end_cap
        return []
      end

      outbound = earliest_positions_from_outbound_titles
      if outbound.any?
        @after_state = :outbound_paths
        outbound
      else
        @after_state = :undefined
        []
      end
    end

    def within_title_after_stage?
      # Levels 1 and 2 step within the title; level 3 (exit) uses title paths.
      minor_slot.nil? || minor_slot < 3
    end

    def earliest_positions_from_outbound_titles
      title.outbound_title_paths.includes(to_title: { positions: :position_level }).filter_map do |path|
        earliest = path.to_title.positions.unarchived.min_by { |p| level_tuple(p) }
        next unless earliest

        Neighbor.new(
          position: earliest,
          path_type_label: path.path_type_label,
          source: :outbound_path
        )
      end
    end
  end
end
