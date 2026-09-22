# frozen_string_literal: true

module MyGrowth
  # Assignments / aspirations that are Meeting (not Exceeding) when the current
  # position requires an exceed % that is not yet met — candidates for create-goal.
  class ExceedExpectationGaps
    Row = Data.define(
      :record,
      :object_label,
      :object_type_label,
      :has_active_goal,
      :active_goal_count,
      :draft_goal_count
    )

    Result = Data.define(
      :applicable,
      :rows,
      :position
    )

    def self.call(organization:, teammate:)
      new(organization: organization, teammate: teammate).call
    end

    def initialize(organization:, teammate:)
      @organization = organization
      @teammate = teammate
    end

    def call
      position = teammate.active_employment_tenure&.position
      return empty_result(position) if position.blank?

      report = PositionEligibilityService.new.check_eligibility(teammate, position)
      conversation = PositionChange::KeystoneEligibilityConversation.call(
        teammate: teammate,
        target_position: position,
        eligibility_report: report
      )

      exceed_rows = conversation.path_rows.select do |row|
        row.reason == PositionChange::KeystoneEligibilityConversation::EXCEED_REASON
      end

      goal_counts = goal_counts_by_key
      rows = exceed_rows.map do |row|
        key = [row.record.class.name, row.record.id]
        counts = goal_counts[key] || { active: 0, draft: 0 }
        Row.new(
          record: row.record,
          object_label: row.object_label,
          object_type_label: row.object_type_label,
          has_active_goal: counts[:active].positive?,
          active_goal_count: counts[:active],
          draft_goal_count: counts[:draft]
        )
      end.sort_by { |r| [r.has_active_goal ? 1 : 0, r.object_type_label, r.object_label.to_s.downcase] }

      Result.new(
        applicable: exceed_rows.any? || checks_require_exceeding?(report),
        rows: rows,
        position: position
      )
    end

    private

    attr_reader :organization, :teammate

    def empty_result(position)
      Result.new(applicable: false, rows: [], position: position)
    end

    def checks_require_exceeding?(report)
      Array(report[:checks]).any? do |check|
        next false unless PositionChange::KeystoneEligibilityConversation::EXCEED_CHECK_KEYS.include?(check[:key])

        details = check[:details] || {}
        details[:minimum_percentage_exceeding].present?
      end
    end

    def goal_counts_by_key
      GoalAssociation
        .joins(:goal)
        .where(goals: {
          owner_type: "CompanyTeammate",
          owner_id: teammate.id,
          completed_at: nil,
          deleted_at: nil
        })
        .where(associable_type: %w[Assignment Aspiration])
        .group("goal_associations.associable_type", "goal_associations.associable_id")
        .pluck(
          Arel.sql("goal_associations.associable_type"),
          Arel.sql("goal_associations.associable_id"),
          Arel.sql("COUNT(*) FILTER (WHERE goals.started_at IS NOT NULL)"),
          Arel.sql("COUNT(*) FILTER (WHERE goals.started_at IS NULL)")
        )
        .each_with_object({}) do |(type, id, active, draft), memo|
          memo[[type, id]] = { active: active.to_i, draft: draft.to_i }
        end
    end
  end
end
