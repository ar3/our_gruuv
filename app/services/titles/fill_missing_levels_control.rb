# frozen_string_literal: true

module Titles
  # Decides what the positions-index "fill missing levels" control should show
  # for a title (one-click clone button vs muted reason). Uses preloaded
  # associations and @required_count on positions when present.
  class FillMissingLevelsControl
    Control = Struct.new(:mode, :message, :source_position, :missing_levels, :available_count, keyword_init: true) do
      def button?
        mode == :button
      end

      def missing_count
        missing_levels&.size.to_i
      end

      def incomplete?
        missing_count.positive?
      end
    end

    def self.for(title)
      new(title).call
    end

    def initialize(title)
      @title = title
    end

    def call
      available_levels = @title.position_major_level.position_levels.to_a
      existing_level_ids = @title.positions.map(&:position_level_id).compact
      missing_levels = available_levels.reject { |level| existing_level_ids.include?(level.id) }
      available_count = available_levels.size

      if missing_levels.empty?
        return Control.new(
          mode: :muted,
          message: "All #{available_count} position level#{'s' if available_count != 1} filled",
          missing_levels: [],
          available_count: available_count
        )
      end

      if @title.positions.empty?
        return Control.new(
          mode: :muted,
          message: "Create a position with at least 2 required assignments before filling other levels (#{missing_levels.size} missing)",
          missing_levels: missing_levels,
          available_count: available_count
        )
      end

      source = source_position
      required_count = required_assignments_count(source)

      if required_count > 1
        Control.new(
          mode: :button,
          source_position: source,
          missing_levels: missing_levels,
          available_count: available_count
        )
      else
        Control.new(
          mode: :muted,
          message: "Source needs at least 2 required assignments to fill #{missing_levels.size} missing level#{'s' if missing_levels.size != 1}",
          missing_levels: missing_levels,
          available_count: available_count
        )
      end
    end

    private

    def source_position
      # Most required assignments; on tie, lowest level string (e.g. 2.1 before 2.2).
      @title.positions.min_by do |position|
        [
          -required_assignments_count(position),
          position.position_level&.level.to_s
        ]
      end
    end

    def required_assignments_count(position)
      if position.instance_variable_defined?(:@required_count)
        position.instance_variable_get(:@required_count).to_i
      else
        position.position_assignments.count { |pa| pa.assignment_type == 'required' }
      end
    end
  end
end
