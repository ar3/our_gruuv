# frozen_string_literal: true

class ManagersViewCardDataService
  RowData = Struct.new(
    :check_in_actions_needed,
    :goals_health_status,
    :active_goals_count,
    :draft_goals_count,
    :ogo_overall_status,
    :ogos_given_30d_count,
    :ogos_received_30d_count,
    keyword_init: true
  )

  def self.load(teammates:, organization:, viewing_teammate:)
    new(teammates: teammates, organization: organization, viewing_teammate: viewing_teammate).load
  end

  def initialize(teammates:, organization:, viewing_teammate:)
    @teammates = Array(teammates)
    @organization = organization
    @viewing_teammate = viewing_teammate
  end

  def load
    return {} if teammates.empty?

    teammate_ids = teammates.map(&:id)
    goals_by_teammate = goals_grouped_by_teammate(teammate_ids)
    goal_eh_by_teammate_id = GoalsHealthEngagementHealthSupport.records_by_teammate_id(
      organization: organization,
      teammate_ids: teammate_ids
    )
    ogo_eh_by_teammate_id = ObservationsHealthEngagementHealthSupport.records_by_teammate_id(
      organization: organization,
      teammate_ids: teammate_ids
    )
    ogo_30d_counts = batch_ogo_30d_counts(teammate_ids)

    teammates.each_with_object({}) do |teammate, rows|
      goals = goals_by_teammate[teammate.id] || []
      ogo_counts = ogo_30d_counts[teammate.id] || { given: 0, received: 0 }
      goal_eh_status = GoalsHealthEngagementHealthSupport.category_status(
        goal_eh_by_teammate_id[teammate.id] || []
      )
      ogo_eh_status = ObservationsHealthEngagementHealthSupport.overall_status(
        ogo_eh_by_teammate_id[teammate.id] || []
      )

      rows[teammate.id] = RowData.new(
        check_in_actions_needed: check_in_actions_needed_for(teammate),
        goals_health_status: GoalsHealthEngagementHealthSupport.spotlight_symbol(goal_eh_status),
        active_goals_count: goals.count { |g| g.deleted_at.nil? && g.completed_at.nil? && g.started_at.present? },
        draft_goals_count: goals.count { |g| g.deleted_at.nil? && g.completed_at.nil? && g.started_at.nil? },
        ogo_overall_status: GoalsHealthEngagementHealthSupport.spotlight_symbol(ogo_eh_status),
        ogos_given_30d_count: ogo_counts[:given],
        ogos_received_30d_count: ogo_counts[:received]
      )
    end
  end

  private

  attr_reader :teammates, :organization, :viewing_teammate

  def goals_grouped_by_teammate(teammate_ids)
    Goal
      .where(owner_type: "CompanyTeammate", owner_id: teammate_ids, company: organization)
      .where(deleted_at: nil)
      .group_by(&:owner_id)
  end

  def check_in_actions_needed_for(teammate)
    return 0 unless teammate.is_a?(CompanyTeammate)

    CheckIns::UpNextActionsCountService.call(
      teammate: teammate,
      organization: organization,
      viewing_teammate: viewing_teammate
    )
  end

  def batch_ogo_30d_counts(teammate_ids)
    cutoff = Observations::HealthRecency::RECENCY_DAYS.days.ago
    teammates_by_id = teammates.index_by(&:id)

    teammate_ids.index_with do |teammate_id|
      teammate = teammates_by_id[teammate_id]
      next { given: 0, received: 0 } unless teammate

      {
        given: Observations::HealthScopes.given_scope(teammate, organization).where(published_at: cutoff..).count,
        received: Observations::HealthScopes.received_scope(teammate, organization).where(published_at: cutoff..).count
      }
    end
  end
end
