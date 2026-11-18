# frozen_string_literal: true

module Goals
  # Flip a draft non-objective goal to progressive_outcome and fill blank OG3 fields.
  class ApplyProgressiveOutcomeDefaults
    Result = Struct.new(:ok?, :applied?, :goal, :error, keyword_init: true)

    def self.call(...) = new(...).call

    def initialize(goal:, attrs:, source: :unknown, check_status: nil, check_summary: nil, check_details: {})
      @goal = goal
      @attrs = attrs.to_h.symbolize_keys
      @source = source.to_s
      @check_status = check_status
      @check_summary = check_summary
      @check_details = check_details.to_h
    end

    def call
      return failure("Goal missing") if @goal.blank?

      Goal.transaction do
        @goal.lock!
        reasons = ProgressiveOutcomeDefaultEligibility.ineligibility_reasons(@goal)
        unless reasons.empty?
          return Result.new(ok?: true, applied?: false, goal: @goal, error: reasons.join("; "))
        end

        updates = build_updates
        aim_present = updates[:outcome_commit].present? ||
          updates[:outcome_stretch].present? ||
          updates[:outcome_transform].present?
        unless aim_present
          return Result.new(ok?: true, applied?: false, goal: @goal, error: "no commit/stretch/transform values to apply")
        end

        type_before = @goal.goal_type
        check_blob = RecordOg3DefaultCheck.format(
          goal: @goal,
          status: @check_status.presence || "applied_#{@source}",
          summary: @check_summary.presence || "Applied OG3 defaults from #{@source}.",
          details: @check_details.merge(
            source: @source,
            goal_type_before: type_before,
            applied_attrs: updates.except(:og3_default_check_result).inspect
          )
        )
        updates[:og3_default_check_result] = check_blob

        @goal.update!(updates)
        Rails.logger.info(
          "[OG3 default] applied source=#{@source} goal_id=#{@goal.id} aim=#{@goal.progressive_current_aim}"
        )
        Result.new(ok?: true, applied?: true, goal: @goal, error: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence.presence || e.message)
    end

    private

    def build_updates
      commit = decimal_or_nil(@attrs[:outcome_commit] || @attrs[:commit])
      stretch = decimal_or_nil(@attrs[:outcome_stretch] || @attrs[:stretch])
      transform = decimal_or_nil(@attrs[:outcome_transform] || @attrs[:transform])
      baseline = decimal_or_nil(@attrs[:outcome_baseline] || @attrs[:baseline])
      unit = @attrs[:outcome_unit].presence || @attrs[:unit].presence
      current_aim = (@attrs[:progressive_current_aim].presence || @attrs[:current_aim].presence ||
        first_available_aim(commit, stretch, transform))

      {
        goal_type: "progressive_outcome",
        outcome_baseline: baseline,
        outcome_commit: commit,
        outcome_stretch: stretch,
        outcome_transform: transform,
        outcome_unit: unit,
        progressive_current_aim: current_aim
      }.compact
    end

    def first_available_aim(commit, stretch, transform)
      return "commit" if commit.present?
      return "stretch" if stretch.present?
      return "transform" if transform.present?

      "commit"
    end

    def decimal_or_nil(value)
      return nil if value.nil? || value.to_s.strip.empty?

      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end

    def failure(message)
      Result.new(ok?: false, applied?: false, goal: @goal, error: message)
    end
  end
end
