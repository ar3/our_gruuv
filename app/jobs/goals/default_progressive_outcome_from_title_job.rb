# frozen_string_literal: true

module Goals
  # Async OG3 defaulting when deterministic prose parse finds nothing.
  class DefaultProgressiveOutcomeFromTitleJob < ApplicationJob
    queue_as :default

    def perform(goal_id, expected_title)
      goal = Goal.find_by(id: goal_id)
      if goal.blank?
        return
      end

      if goal.title.to_s != expected_title.to_s
        RecordOg3DefaultCheck.persist!(
          goal: goal,
          status: "llm_skipped_title_changed",
          summary: "LLM OG3 check aborted because the title changed since enqueue.",
          details: {
            expected_title: expected_title.to_s.truncate(240),
            current_title: goal.title.to_s.truncate(240)
          }
        )
        return
      end

      reasons = ProgressiveOutcomeDefaultEligibility.ineligibility_reasons(goal)
      unless reasons.empty?
        RecordOg3DefaultCheck.persist!(
          goal: goal,
          status: "llm_skipped_ineligible",
          summary: "LLM OG3 check aborted because eligibility gates failed when the job ran.",
          details: { reasons: reasons.join("; ") }
        )
        return
      end

      suggestion = Llm::ProgressiveOutcomeTitleSuggester.call(goal: goal)
      unless suggestion.apply?
        RecordOg3DefaultCheck.persist!(
          goal: goal,
          status: "llm_declined",
          summary: "LLM OG3 check ran and did not convert the goal (low confidence or not progressive).",
          details: {
            confidence: suggestion.confidence,
            rationale: suggestion.rationale.to_s.truncate(400),
            commit: suggestion.commit,
            stretch: suggestion.stretch,
            transform: suggestion.transform,
            unit: suggestion.unit
          }
        )
        return
      end

      result = ApplyProgressiveOutcomeDefaults.call(
        goal: goal,
        source: :llm,
        attrs: {
          baseline: suggestion.baseline,
          commit: suggestion.commit,
          stretch: suggestion.stretch,
          transform: suggestion.transform,
          unit: suggestion.unit,
          current_aim: suggestion.current_aim
        },
        check_status: "llm_applied",
        check_summary: "LLM OG3 check converted the goal to progressive_outcome and filled fields.",
        check_details: {
          confidence: suggestion.confidence,
          rationale: suggestion.rationale.to_s.truncate(400)
        }
      )

      return if result.applied?

      RecordOg3DefaultCheck.persist!(
        goal: goal,
        status: "llm_matched_but_not_applied",
        summary: "LLM OG3 check wanted to convert, but apply did not change the goal.",
        details: {
          error: result.error,
          confidence: suggestion.confidence,
          rationale: suggestion.rationale.to_s.truncate(400)
        }
      )
    end
  end
end
