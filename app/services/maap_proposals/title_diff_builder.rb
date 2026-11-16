# frozen_string_literal: true

module MaapProposals
  class TitleDiffBuilder
    FieldDiff = Data.define(:key, :label, :before, :after)

    LABELS = {
      "external_title" => "External title",
      "position_major_level_id" => "Position major level",
      "department_id" => "Department",
      "position_summary" => "Position summary",
      "alternative_titles" => "Alternative titles"
    }.freeze

    def self.call(before:, after:)
      new(before: before, after: after).call
    end

    def initialize(before:, after:)
      @before = before.is_a?(TitlePayload) ? before.to_h : TitlePayload.from_hash(before).to_h
      @after = after.is_a?(TitlePayload) ? after.to_h : TitlePayload.from_hash(after).to_h
    end

    def call
      TitlePayload::ATTR_KEYS.filter_map do |key|
        before_val = @before[key]
        after_val = @after[key]
        next if before_val == after_val

        FieldDiff.new(
          key: key,
          label: LABELS.fetch(key, key.humanize),
          before: display(key, before_val),
          after: display(key, after_val)
        )
      end
    end

    private

    def display(key, value)
      return "—" if value.nil? || value.to_s.strip.empty?

      case key
      when "position_major_level_id"
        PositionMajorLevel.find_by(id: value)&.display_name || value
      when "department_id"
        Department.find_by(id: value)&.name || value
      else
        value
      end
    end
  end
end
