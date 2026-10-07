# Powers the "Something Interesting" tab of Get Shit Done: things other people
# have done since `since` (usually the viewer's last visit to that page) that
# the viewing teammate likely cares about. The viewer's own activity is
# excluded wherever it can be attributed (check-in reporter, PaperTrail whodunnit).
# Also includes calendar moments when a check-in first reaches Warning (day 61
# after the last finalize) for the viewer and their direct reports.
class SomethingInterestingQueryService
  GoalActivity = Struct.new(:goal, :record_updated, :new_check_ins, keyword_init: true) do
    def latest_activity_at
      [record_updated ? goal.updated_at : nil, new_check_ins.map(&:created_at).max].compact.max
    end
  end

  # One clarity item whose check-in freshness crossed into Warning in the window.
  CheckInWarningEvent = Struct.new(
    :subject_teammate,
    :entity_type,
    :entity,
    :reached_at,
    :last_finalized_at,
    keyword_init: true
  ) do
    def entity_name
      case entity_type
      when 'Assignment' then entity.title
      when 'Position' then entity.display_name
      when 'Aspiration' then entity.name
      else entity.try(:title) || entity.try(:name) || entity.to_s
      end
    end

    def type_label
      entity_type == 'Aspiration' ? 'Value' : entity_type
    end
  end

  # First Warning day is the day after the healthy window (days 0–60 healthy).
  WARNING_REACHED_OFFSET_DAYS = EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS + 1

  # Header pill cache: SI queries are heavy; 1h is fine, and SI visits reset the entry.
  HEADER_PENDING_COUNT_CACHE_EXPIRES_IN = 1.hour

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

  def self.header_pending_count_cache_key(teammate)
    ['header_si_pending_count', teammate.id]
  end

  # Memoized header badge count (same baseline as the SI tab).
  def self.header_pending_count(teammate)
    return 0 unless teammate

    Rails.cache.fetch(
      header_pending_count_cache_key(teammate),
      expires_in: HEADER_PENDING_COUNT_CACHE_EXPIRES_IN
    ) do
      new(teammate: teammate, since: baseline(teammate)).total_count
    end
  end

  # After a SI page visit, header should not keep showing a non-zero cached count.
  # Write 0 rather than delete — PageVisit is recorded async, so a cold recompute
  # right after visit would still use the pre-visit baseline and re-cache a positive count.
  def self.bust_header_pending_count_cache!(teammate)
    return unless teammate

    Rails.cache.write(
      header_pending_count_cache_key(teammate),
      0,
      expires_in: HEADER_PENDING_COUNT_CACHE_EXPIRES_IN
    )
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

  # Day a required-clarity check-in first reaches Warning (after a prior finalize)
  # for the viewer's active assignments, position, and values (aspirations).
  def check_in_warnings_for_me
    return [] unless teammate

    check_in_warning_events_for([teammate])
  end

  # Same Warning-day moments for direct reports.
  def check_in_warnings_for_those_i_serve
    return [] unless teammate
    return [] if direct_report_ids.empty?

    reports = CompanyTeammate.where(id: direct_report_ids).includes(:person).to_a
    check_in_warning_events_for(reports)
  end

  def total_count
    goals_updated_by_those_i_serve.size +
      goals_updated_on_my_teams.size +
      assignments_updated.size +
      abilities_updated.size +
      observations_about_those_i_serve.count +
      observations_about_me.count +
      observation_comments.size +
      check_in_warnings_for_me.size +
      check_in_warnings_for_those_i_serve.size
  end

  # Comments on published OGOs where the viewer is the observer, an observee,
  # or a prior commenter (and can still see the OGO). Own comments excluded.
  def observation_comments
    return [] unless teammate

    Comment
      .where(organization_id: company.id)
      .where('comments.created_at > ?', since)
      .where.not(creator_id: person.id)
      .includes(:creator, :commentable)
      .order(created_at: :desc)
      .select { |comment| interesting_observation_comment?(comment) }
  end

  private

  def check_in_warning_events_for(subjects)
    subjects = Array(subjects).compact
    return [] if subjects.empty?

    (
      assignment_check_in_warning_events(subjects) +
      position_check_in_warning_events(subjects) +
      aspiration_check_in_warning_events(subjects)
    ).select { |event| warning_reached_in_window?(event.reached_at) }
     .sort_by { |event| -event.reached_at.to_i }
  end

  def warning_reached_in_window?(reached_at)
    reached_at.present? && reached_at > since && reached_at <= Time.current
  end

  def warning_reached_at(last_finalized_at)
    return nil if last_finalized_at.blank?

    (last_finalized_at.to_date + WARNING_REACHED_OFFSET_DAYS).beginning_of_day
  end

  def assignment_check_in_warning_events(subjects)
    subjects_by_id = subjects.index_by(&:id)
    tenures = AssignmentTenure
      .active_and_given_energy
      .where(teammate_id: subjects_by_id.keys)
      .includes(:assignment)

    pairs = tenures.filter_map do |tenure|
      next if tenure.assignment.blank? || tenure.assignment.deleted_at.present?

      [tenure.teammate_id, tenure.assignment_id]
    end.uniq
    return [] if pairs.empty?

    latest_by_pair = latest_closed_assignment_check_ins(pairs)
    assignments_by_id = Assignment.where(id: pairs.map(&:last).uniq).index_by(&:id)

    pairs.filter_map do |teammate_id, assignment_id|
      last_finalized_at = latest_by_pair[[teammate_id, assignment_id]]
      reached_at = warning_reached_at(last_finalized_at)
      next unless reached_at

      assignment = assignments_by_id[assignment_id]
      subject = subjects_by_id[teammate_id]
      next unless assignment && subject

      CheckInWarningEvent.new(
        subject_teammate: subject,
        entity_type: 'Assignment',
        entity: assignment,
        reached_at: reached_at,
        last_finalized_at: last_finalized_at
      )
    end
  end

  def latest_closed_assignment_check_ins(pairs)
    teammate_ids = pairs.map(&:first).uniq
    assignment_ids = pairs.map(&:last).uniq
    AssignmentCheckIn
      .closed
      .where(teammate_id: teammate_ids, assignment_id: assignment_ids)
      .group(:teammate_id, :assignment_id)
      .maximum(:official_check_in_completed_at)
  end

  def position_check_in_warning_events(subjects)
    subjects_by_id = subjects.index_by(&:id)
    tenures = EmploymentTenure
      .active
      .where(teammate_id: subjects_by_id.keys, company: company)
      .includes(:position)
      .order(started_at: :desc)

    # One active employment tenure / position per subject (most recent started).
    tenure_by_teammate_id = {}
    tenures.each do |tenure|
      tenure_by_teammate_id[tenure.teammate_id] ||= tenure
    end
    return [] if tenure_by_teammate_id.empty?

    latest_by_teammate = PositionCheckIn
      .closed
      .where(teammate_id: tenure_by_teammate_id.keys)
      .group(:teammate_id)
      .maximum(:official_check_in_completed_at)

    tenure_by_teammate_id.filter_map do |teammate_id, tenure|
      position = tenure.position
      next unless position

      last_finalized_at = latest_by_teammate[teammate_id]
      reached_at = warning_reached_at(last_finalized_at)
      next unless reached_at

      CheckInWarningEvent.new(
        subject_teammate: subjects_by_id[teammate_id],
        entity_type: 'Position',
        entity: position,
        reached_at: reached_at,
        last_finalized_at: last_finalized_at
      )
    end
  end

  def aspiration_check_in_warning_events(subjects)
    aspirations = Aspiration.for_company(company).ordered.to_a
    return [] if aspirations.empty?

    subjects_by_id = subjects.index_by(&:id)
    aspiration_ids = aspirations.map(&:id)
    aspirations_by_id = aspirations.index_by(&:id)

    latest_by_pair = AspirationCheckIn
      .closed
      .where(teammate_id: subjects_by_id.keys, aspiration_id: aspiration_ids)
      .group(:teammate_id, :aspiration_id)
      .maximum(:official_check_in_completed_at)

    subjects_by_id.keys.product(aspiration_ids).filter_map do |teammate_id, aspiration_id|
      last_finalized_at = latest_by_pair[[teammate_id, aspiration_id]]
      reached_at = warning_reached_at(last_finalized_at)
      next unless reached_at

      CheckInWarningEvent.new(
        subject_teammate: subjects_by_id[teammate_id],
        entity_type: 'Aspiration',
        entity: aspirations_by_id[aspiration_id],
        reached_at: reached_at,
        last_finalized_at: last_finalized_at
      )
    end
  end

  def interesting_observation_comment?(comment)
    root = comment.root_commentable
    return false unless root.is_a?(::Observation)
    return false unless root.published? && !root.soft_deleted?
    return false unless observation_comment_audience?(root)
    return false unless observation_visible?(root)

    true
  end

  def observation_comment_audience?(observation)
    return true if observation.observer_id == person.id
    return true if observation.observees.exists?(teammate_id: teammate.id)

    viewer_commented_on_observation?(observation)
  end

  def viewer_commented_on_observation?(observation)
    return true if Comment.exists?(commentable: observation, creator_id: person.id)

    Comment.where(creator_id: person.id, organization_id: company.id).any? do |c|
      c.root_commentable == observation
    end
  end

  def observation_visible?(observation)
    ObservationVisibilityQuery.new(person, company).visible_observations.where(id: observation.id).exists?
  end

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
