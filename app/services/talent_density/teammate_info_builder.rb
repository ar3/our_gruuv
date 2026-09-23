# frozen_string_literal: true

module TalentDensity
  # Context card data for the Confidential Talent Reflection working page.
  class TeammateInfoBuilder
    ASSOCIABLE_TYPES = %w[Assignment Ability Aspiration].freeze

    Info = Struct.new(
      :employed_since_at,
      :position_change_at,
      :from_position,
      :to_position,
      :latest_finalized_check_in,
      :target_position,
      :active_goals_count,
      :active_goals_latest_completion_date,
      :experiences_summary,
      keyword_init: true
    )

    def self.call(teammates:, company:, viewer_teammate: nil)
      new(teammates: teammates, company: company, viewer_teammate: viewer_teammate).call
    end

    def initialize(teammates:, company:, viewer_teammate: nil)
      @teammates = Array(teammates)
      @company = company
      @viewer_teammate = viewer_teammate
    end

    def call
      return {} if @teammates.empty?

      ids = @teammates.map(&:id)
      tenures_by_id = tenures_by_teammate_id(ids)
      goals_by_id = active_goals_stats_by_teammate_id(ids)
      finalized_by_id = latest_finalized_by_teammate_id(ids)

      @teammates.index_with do |teammate|
        history = tenures_by_id[teammate.id] || []
        current, previous = current_and_previous_tenure(history)
        goals = goals_by_id[teammate.id] || { count: 0, latest_completion_date: nil }

        Info.new(
          employed_since_at: teammate.first_employed_at,
          position_change_at: previous && current ? current.started_at : nil,
          from_position: previous&.position,
          to_position: previous && current ? current.position : nil,
          latest_finalized_check_in: finalized_by_id[teammate.id],
          target_position: teammate.next_goal_position,
          active_goals_count: goals[:count],
          active_goals_latest_completion_date: goals[:latest_completion_date],
          experiences_summary: MyGrowth::ExperiencesSummary.for_teammate(
            teammate,
            organization: @company,
            viewer_teammate: @viewer_teammate
          )
        )
      end.transform_keys(&:id)
    end

    private

    def tenures_by_teammate_id(ids)
      EmploymentTenure
        .where(company: @company, teammate_id: ids)
        .includes(position: [:title, :position_level])
        .order(:started_at)
        .group_by(&:teammate_id)
    end

    def latest_finalized_by_teammate_id(ids)
      PositionCheckIn
        .where(teammate_id: ids)
        .closed
        .includes(
          :employment_tenure,
          employment_tenure: { position: [:title, :position_level] },
          manager_completed_by_teammate: :person,
          finalized_by_teammate: :person
        )
        .order(official_check_in_completed_at: :desc)
        .group_by(&:teammate_id)
        .transform_values(&:first)
    end

    def active_goals_stats_by_teammate_id(ids)
      rows = GoalAssociation
        .joins(:goal)
        .where(associable_type: ASSOCIABLE_TYPES)
        .where(goals: { owner_type: "CompanyTeammate", owner_id: ids })
        .merge(Goal.incomplete_unarchived)
        .pluck("goals.owner_id", "goals.id", "goals.most_likely_target_date")

      by_owner = Hash.new { |h, k| h[k] = { goal_ids: Set.new, dates: [] } }
      rows.each do |owner_id, goal_id, target_date|
        by_owner[owner_id][:goal_ids] << goal_id
        by_owner[owner_id][:dates] << target_date if target_date.present?
      end

      ids.index_with do |id|
        stats = by_owner[id]
        {
          count: stats[:goal_ids].size,
          latest_completion_date: stats[:dates].max
        }
      end
    end

    def current_and_previous_tenure(history)
      return [nil, nil] if history.blank?

      sorted = history.sort_by(&:started_at)
      current = sorted.reverse.find { |tenure| tenure.ended_at.nil? } || sorted.last
      index = sorted.index(current)
      previous = index && index.positive? ? sorted[index - 1] : nil
      [current, previous]
    end
  end
end
