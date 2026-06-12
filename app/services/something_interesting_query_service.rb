# Powers the "Something Interesting" tab of Get Shit Done: things other people
# have done since `since` (usually the viewer's last visit to that page) that
# the viewing teammate likely cares about. The viewer's own activity is
# excluded wherever it can be attributed (check-in reporter, PaperTrail whodunnit).
class SomethingInterestingQueryService
  GoalActivity = Struct.new(:goal, :record_updated, :new_check_ins, keyword_init: true) do
    def latest_activity_at
      [record_updated ? goal.updated_at : nil, new_check_ins.map(&:created_at).max].compact.max
    end
  end

  attr_reader :teammate, :person, :company, :since

  # Last visit to the Something Interesting page (with or without query params).
  def self.last_visited_at(teammate)
    path = Rails.application.routes.url_helpers
                .something_interesting_organization_get_shit_done_path(teammate.organization)
    PageVisit.where(person: teammate.person)
             .where('url = ? OR url LIKE ?', path, "#{path}?%")
             .maximum(:visited_at)
  end

  # Default window: everything since the last page visit, or the past 7 days if never visited.
  def self.baseline(teammate)
    last_visited_at(teammate) || 7.days.ago
  end

  def initialize(teammate:, since:)
    @teammate = teammate
    @person = teammate&.person
    @company = teammate&.organization
    @since = since
  end

  def goals_updated_by_those_i_serve
    return [] unless teammate
    return [] if direct_report_ids.empty?

    goal_activities_for(Goal.where(owner_type: 'CompanyTeammate', owner_id: direct_report_ids))
  end

  def goals_updated_on_my_teams
    return [] unless teammate
    return [] if my_team_ids.empty?

    goal_activities_for(Goal.where(owner_type: 'Team', owner_id: my_team_ids))
  end

  def assignments_updated
    return [] unless teammate
    return [] if interested_assignment_ids.empty?

    Assignment.where(id: interested_assignment_ids, deleted_at: nil)
              .where('updated_at > ?', since)
              .order(updated_at: :desc)
              .select { |assignment| updated_by_someone_else?(assignment) }
  end

  def abilities_updated
    return [] unless teammate
    return [] if interested_ability_ids.empty?

    Ability.where(id: interested_ability_ids, deleted_at: nil)
           .where('updated_at > ?', since)
           .order(updated_at: :desc)
           .select { |ability| updated_by_someone_else?(ability) }
  end

  def observations_about_those_i_serve
    return Observation.none unless teammate

    observations_about(direct_report_ids)
  end

  def observations_about_me
    return Observation.none unless teammate

    observations_about([teammate.id])
  end

  def total_count
    goals_updated_by_those_i_serve.size +
      goals_updated_on_my_teams.size +
      assignments_updated.size +
      abilities_updated.size +
      observations_about_those_i_serve.count +
      observations_about_me.count
  end

  private

  def observations_about(teammate_ids)
    return Observation.none if teammate_ids.empty?

    ObservationVisibilityQuery.new(person, company).visible_observations
                              .where('observations.published_at > ?', since)
                              .where.not(observer_id: person.id)
                              .joins(:observees)
                              .where(observees: { teammate_id: teammate_ids })
                              .distinct
                              .order(published_at: :desc)
  end

  def goal_activities_for(scope)
    candidates = scope
      .where(company: company, deleted_at: nil)
      .where(
        'goals.updated_at > :since OR EXISTS (SELECT 1 FROM goal_check_ins WHERE goal_check_ins.goal_id = goals.id AND goal_check_ins.created_at > :since)',
        since: since
      )
      .includes(:owner, :creator)

    candidates.filter_map do |goal|
      next unless goal.can_be_viewed_by?(person)

      new_check_ins = goal.goal_check_ins
                          .where('created_at > ?', since)
                          .where.not(confidence_reporter_id: person.id)
                          .order(created_at: :desc)
                          .to_a
      record_updated = goal.updated_at > since && updated_by_someone_else?(goal)
      next if new_check_ins.empty? && !record_updated

      GoalActivity.new(goal: goal, record_updated: record_updated, new_check_ins: new_check_ins)
    end.sort_by { |activity| -activity.latest_activity_at.to_i }
  end

  # True when any change since `since` can't be attributed to the viewer.
  # Whodunnit is the acting CompanyTeammate id; if there are no versions we
  # can't attribute the update, so we include it.
  def updated_by_someone_else?(record)
    versions = PaperTrail::Version.where(item_type: record.class.name, item_id: record.id)
                                  .where('created_at > ?', since)
    return true if versions.empty?

    versions.any? { |version| version.whodunnit.blank? || version.whodunnit.to_s != teammate.id.to_s }
  end

  def direct_report_ids
    @direct_report_ids ||= EmploymentTenure.where(manager_teammate: teammate, company: company, ended_at: nil)
                                           .distinct
                                           .pluck(:teammate_id)
  end

  def my_team_ids
    @my_team_ids ||= TeamMember.where(company_teammate: teammate).pluck(:team_id)
  end

  def interested_assignment_ids
    @interested_assignment_ids ||= begin
      tenure_ids = teammate.assignment_tenures
                           .where(ended_at: nil)
                           .where('anticipated_energy_percentage > 0')
                           .pluck(:assignment_id)
      position_ids = current_position ? current_position.assignments.pluck(:id) : []
      (tenure_ids + position_ids).uniq
    end
  end

  def interested_ability_ids
    @interested_ability_ids ||= begin
      assignment_ability_ids = if interested_assignment_ids.any?
        Ability.joins(:assignment_abilities)
               .where(assignment_abilities: { assignment_id: interested_assignment_ids })
               .pluck(:id)
      else
        []
      end
      position_ability_ids = current_position ? current_position.abilities.pluck(:id) : []
      milestone_ability_ids = teammate.teammate_milestones.pluck(:ability_id)
      (assignment_ability_ids + position_ability_ids + milestone_ability_ids).uniq
    end
  end

  def current_position
    return @current_position if defined?(@current_position)

    @current_position = teammate.employment_tenures.active.order(started_at: :desc).first&.position
  end
end
