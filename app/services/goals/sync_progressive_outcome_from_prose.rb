# frozen_string_literal: true

module Goals
  # Sync structured Progressive Outcome fields from title prose unless
  # advanced users have manually edited fields since the last prose sync.
  class SyncProgressiveOutcomeFromProse
    def self.call(...) = new(...).call

    def initialize(goal:, force: false)
      @goal = goal
      @force = force
    end

    def call
      return Result.ok(goal: @goal, synced: false) unless @goal.progressive_outcome?
      return Result.ok(goal: @goal, synced: false) if !@force && @goal.outcome_fields_manually_edited_at.present?

      parsed = ProgressiveOutcomeProse.parse(@goal.title)
      attrs = {
        outcome_baseline: parsed.baseline,
        outcome_commit: parsed.commit,
        outcome_stretch: parsed.stretch,
        outcome_transform: parsed.transform,
        outcome_unit: parsed.unit
      }.compact

      return Result.ok(goal: @goal, synced: false, parsed: parsed) if attrs.empty?

      if @goal.progressive_current_aim.blank?
        attrs[:progressive_current_aim] = first_available_aim(parsed)
      end

      @goal.assign_attributes(attrs)
      Result.ok(goal: @goal, synced: true, parsed: parsed)
    end

    Result = Struct.new(:ok?, :goal, :synced, :parsed, :error, keyword_init: true) do
      def self.ok(**kwargs) = new(ok?: true, error: nil, **kwargs)
      def self.err(error) = new(ok?: false, goal: nil, synced: false, parsed: nil, error: error)
    end

    private

    def first_available_aim(parsed)
      return "commit" if parsed.commit.present?
      return "stretch" if parsed.stretch.present?
      return "transform" if parsed.transform.present?

      "commit"
    end
  end
end
