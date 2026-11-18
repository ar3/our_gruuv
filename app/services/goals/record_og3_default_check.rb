# frozen_string_literal: true

module Goals
  # Persists a human-readable OG3 auto-default audit blob on Goal#og3_default_check_result.
  # Uses a normal +update!+ so PaperTrail records it on the change-history page.
  class RecordOg3DefaultCheck
    def self.format(goal:, status:, summary:, details: {})
      new(goal: goal, status: status, summary: summary, details: details).format
    end

    def self.persist!(goal:, status:, summary:, details: {}, extra_attrs: {})
      new(goal: goal, status: status, summary: summary, details: details).persist!(extra_attrs: extra_attrs)
    end

    def initialize(goal:, status:, summary:, details: {})
      @goal = goal
      @status = status.to_s
      @summary = summary.to_s
      @details = details.to_h
    end

    def format
      lines = [
        "[#{Time.current.utc.strftime("%Y-%m-%d %H:%M:%S UTC")}] status=#{@status}",
        "summary: #{@summary}",
        "title: #{@goal.title.to_s.truncate(240)}",
        "goal_type: #{@goal.goal_type}",
        "started_at: #{@goal.started_at.present? ? @goal.started_at.utc.iso8601 : "nil"}",
        "digit_chars: #{@goal.title.to_s.scan(/\d/).size}",
        "progressive_fields_present: #{progressive_fields_snapshot}",
        "manual_lock: #{@goal.outcome_fields_manually_edited_at.present?}"
      ]
      @details.each do |key, value|
        next if value.nil? || (value.respond_to?(:empty?) && value.empty?)

        lines << "#{key}: #{value}"
      end
      lines.join("\n")
    end

    def persist!(extra_attrs: {})
      return if @goal.blank?

      attrs = extra_attrs.to_h.symbolize_keys.merge(og3_default_check_result: format)
      @goal.update!(attrs)
      @goal
    end

    private

    def progressive_fields_snapshot
      {
        baseline: @goal.outcome_baseline,
        commit: @goal.outcome_commit,
        stretch: @goal.outcome_stretch,
        transform: @goal.outcome_transform,
        unit: @goal.outcome_unit,
        current_aim: @goal.progressive_current_aim
      }.inspect
    end
  end
end
