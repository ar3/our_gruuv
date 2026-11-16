# frozen_string_literal: true

module MaapProposals
  class PositionDiffBuilder
    FieldDiff = Data.define(:key, :label, :before, :after)

    LABELS = {
      "title_id" => "Title",
      "position_level_id" => "Position level",
      "position_level_hint" => "Position level hint",
      "position_summary" => "Position summary",
      "assignment_links" => "Assignment links"
    }.freeze

    def self.call(before:, after:)
      new(before: before, after: after).call
    end

    def initialize(before:, after:)
      @before = before.is_a?(PositionPayload) ? before.to_h : PositionPayload.from_hash(before).to_h
      @after = after.is_a?(PositionPayload) ? after.to_h : PositionPayload.from_hash(after).to_h
    end

    def call
      PositionPayload::ATTR_KEYS.filter_map do |key|
        next if key == "title_proposal_id"

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
      return "—" if value.nil? || (value.respond_to?(:empty?) && value.empty?)

      case key
      when "title_id"
        Title.find_by(id: value)&.external_title || value
      when "position_level_id"
        PositionLevel.find_by(id: value)&.level || value
      when "assignment_links"
        Array(value).map { |link| format_link(link) }.join("; ").presence || "—"
      else
        value
      end
    end

    def format_link(link)
      link = link.deep_stringify_keys
      assignment = Assignment.find_by(id: link["assignment_id"])
      name = assignment&.title || "Assignment ##{link['assignment_id']}"
      type = link["assignment_type"].presence || "required"
      energy = link["energy_percentage"]
      energy.present? ? "#{name} (#{type}, #{energy}%)" : "#{name} (#{type})"
    end
  end
end
