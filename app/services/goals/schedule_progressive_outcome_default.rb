# frozen_string_literal: true

module Goals
  # After a draft goal is persisted: try deterministic title prose first; otherwise enqueue
  # a cheap LLM job when eligibility gates pass. Call only after successful save.
  # Always writes Goal#og3_default_check_result so PaperTrail shows why we did/didn't convert.
  class ScheduleProgressiveOutcomeDefault
    def self.call(goal, title_changed: nil)
      new(goal, title_changed: title_changed).call
    end

    def initialize(goal, title_changed: nil)
      @goal = goal
      @title_changed = title_changed
    end

    def call
      return if @goal.blank?

      unless title_change_gate?
        record(
          status: "skipped_title_unchanged",
          summary: "OG3 defaulting did not run because the title did not change on this save (and this was not a create)."
        )
        return
      end

      reasons = ProgressiveOutcomeDefaultEligibility.ineligibility_reasons(@goal)
      unless reasons.empty?
        record(
          status: "skipped_ineligible",
          summary: "OG3 defaulting did not run because eligibility gates failed.",
          details: { reasons: reasons.join("; ") }
        )
        return
      end

      parsed = ProgressiveOutcomeProse.parse(@goal.title)
      if meaningful_parse?(parsed)
        result = ApplyProgressiveOutcomeDefaults.call(
          goal: @goal,
          source: :prose,
          attrs: {
            baseline: parsed.baseline,
            commit: parsed.commit,
            stretch: parsed.stretch,
            transform: parsed.transform,
            unit: parsed.unit
          },
          check_status: "applied_prose",
          check_summary: "Deterministic title prose matched. Converted to progressive_outcome and filled OG3 fields.",
          check_details: {
            parsed: {
              baseline: parsed.baseline,
              commit: parsed.commit,
              stretch: parsed.stretch,
              transform: parsed.transform,
              unit: parsed.unit
            }.inspect
          }
        )
        unless result.applied?
          record(
            status: "prose_matched_but_not_applied",
            summary: "Deterministic prose matched, but apply did not change the goal (#{result.error || "re-check failed"}).",
            details: {
              parsed: {
                baseline: parsed.baseline,
                commit: parsed.commit,
                stretch: parsed.stretch,
                transform: parsed.transform,
                unit: parsed.unit
              }.inspect
            }
          )
        end
        return
      end

      DefaultProgressiveOutcomeFromTitleJob.perform_later(@goal.id, @goal.title.to_s)
      record(
        status: "enqueued_llm",
        summary: "Deterministic prose found nothing. Enqueued Nova 2 Lite OG3 title check job.",
        details: { expected_title: @goal.title.to_s.truncate(240) }
      )
    end

    private

    def title_change_gate?
      return @title_changed unless @title_changed.nil?

      @goal.previously_new_record? || @goal.saved_change_to_title?
    end

    def meaningful_parse?(parsed)
      parsed.commit.present? || parsed.stretch.present? || parsed.transform.present?
    end

    def record(status:, summary:, details: {})
      RecordOg3DefaultCheck.persist!(
        goal: @goal,
        status: status,
        summary: summary,
        details: details
      )
    end
  end
end
