class ObservationsQuery
  attr_reader :organization, :params, :current_person

  def initialize(organization, params = {}, current_person: nil)
    @organization = organization
    @params = params
    @current_person = current_person
  end

  def call
    observations = base_scope
    observations = filter_by_privacy_levels(observations)
    observations = filter_by_timeframe(observations)
    observations = filter_by_draft_status(observations)
    observations = filter_by_observer(observations)
    observations = filter_by_involving_teammate(observations)
    observations = filter_by_observee_ids(observations)
    observations = filter_by_rateable(observations)
    observations = filter_by_observation_type(observations)
    observations = filter_by_soft_deleted_status(observations)
    observations = apply_sort(observations)
    observations
  end

  def current_filters
    filters = {}
    filters[:privacy] = params[:privacy] if params[:privacy].present?
    filters[:timeframe] = params[:timeframe] if params[:timeframe].present? && params[:timeframe] != 'all'
    if params[:timeframe] == 'between'
      filters[:timeframe_start_date] = params[:timeframe_start_date] if params[:timeframe_start_date].present?
      filters[:timeframe_end_date] = params[:timeframe_end_date] if params[:timeframe_end_date].present?
    end
    filters[:include_soft_deleted] = params[:include_soft_deleted] if params[:include_soft_deleted].present?
    involving_teammate_ids = Array(params[:involving_teammate_ids]).reject(&:blank?)
    if involving_teammate_ids.any?
      filters[:involving_teammate_ids] = involving_teammate_ids
    elsif params[:involving_teammate_id].present?
      filters[:involving_teammate_id] = params[:involving_teammate_id]
    end
    filters[:rateable_type] = params[:rateable_type] if params[:rateable_type].present?
    filters[:rateable_id] = params[:rateable_id] if params[:rateable_id].present?
    filters[:observation_type] = params[:observation_type] if params[:observation_type].present?
    filters
  end

  def current_sort
    params[:sort] || 'observed_at_desc'
  end

  def current_view
    return params[:view] unless params[:view].blank?
    return params[:viewStyle] unless params[:viewStyle].blank?
    'large_list'
  end

  def current_spotlight
    params[:spotlight] || 'most_observed'
  end

  def has_active_filters?
    current_filters.any?
  end

  # Expose base_scope and filter methods for controller to use for counting
  def base_scope
    @base_scope ||= begin
      # Use ObservationVisibilityQuery for complex visibility logic
      visibility_query = ObservationVisibilityQuery.new(current_person, organization)
      visibility_query.visible_observations
    end
  end

  def filter_by_privacy_levels(observations)
    return observations unless params[:privacy].present?

    privacy_levels = Array(params[:privacy])
    return observations if privacy_levels.empty?

    observations.where(privacy_level: privacy_levels)
  end

  def filter_by_timeframe(observations)
    return observations unless params[:timeframe].present?
    return observations if params[:timeframe] == 'all'

    case params[:timeframe]
    when 'this_week'
      observations.where(observed_at: 1.week.ago..)
    when 'this_month'
      observations.where(observed_at: 1.month.ago..)
    when 'this_quarter'
      # Calculate start of current quarter
      now = Time.current
      quarter_start_month = ((now.month - 1) / 3) * 3 + 1
      quarter_start = Time.zone.local(now.year, quarter_start_month, 1).beginning_of_day
      observations.where(observed_at: quarter_start..)
    when 'last_45_days'
      observations.where(observed_at: 45.days.ago..)
    when 'last_90_days'
      observations.where(observed_at: 90.days.ago..)
    when 'this_year'
      observations.where(observed_at: Time.current.beginning_of_year..)
    when 'between'
      start_date = params[:timeframe_start_date]
      end_date = params[:timeframe_end_date]
      if start_date.present? && end_date.present?
        start_time = Date.parse(start_date).beginning_of_day
        end_time = Date.parse(end_date).end_of_day
        observations.where(observed_at: start_time..end_time)
      else
        observations
      end
    else
      observations
    end
  end

  def filter_by_draft_status(observations)
    return observations unless params[:draft].present?
    
    case params[:draft]
    when 'true', true
      observations.where(published_at: nil)
    when 'false', false
      observations.where.not(published_at: nil)
    else
      observations
    end
  end

  def filter_by_observer(observations)
    return observations unless params[:observer_id].present?

    observations = observations.merge(Observation.published).merge(Observation.not_journal)
    observations = observations.where(observer_id: params[:observer_id])

    if params[:exclude_observer_as_observee].present? &&
       (params[:exclude_observer_as_observee] == true || params[:exclude_observer_as_observee].to_s == 'true')
      observer_teammate_ids = CompanyTeammate.where(organization: organization, person_id: params[:observer_id]).select(:id)
      self_observation_ids = Observation.joins(:observees)
                                       .where(observer_id: params[:observer_id])
                                       .where(observees: { teammate_id: observer_teammate_ids })
                                       .select(:id)
      observations = observations.where.not(id: self_observation_ids)
    end

    observations
  end

  def filter_by_involving_teammate(observations)
    teammate_ids = Array(params[:involving_teammate_ids]).reject(&:blank?)
    teammate_ids = [params[:involving_teammate_id]] if teammate_ids.empty? && params[:involving_teammate_id].present?
    return observations if teammate_ids.empty?

    teammates = CompanyTeammate.where(organization: organization, id: teammate_ids)
    return observations if teammates.none?

    person_ids = teammates.select(:person_id)
    observed_ids = Observee.where(teammate_id: teammates.select(:id)).select(:observation_id)
    observations.where(observer_id: person_ids).or(observations.where(id: observed_ids)).distinct
  end

  def filter_by_observee_ids(observations)
    observee_ids = Array(params[:observee_ids]).reject(&:blank?)
    return observations if observee_ids.empty?

    observations = observations.joins(:observees).where(observees: { teammate_id: observee_ids }).distinct
    observations = observations.merge(Observation.published).merge(Observation.not_journal)
    observations
  end

  def filter_by_rateable(observations)
    rateable_type = params[:rateable_type].to_s.presence
    rateable_id = params[:rateable_id].presence
    return observations unless rateable_type && rateable_id

    allowed = %w[Assignment Ability Aspiration]
    return observations unless allowed.include?(rateable_type)

    observations
      .joins(:observation_ratings)
      .where(observation_ratings: { rateable_type: rateable_type, rateable_id: rateable_id })
      .distinct
  end

  def filter_by_observation_type(observations)
    ot = params[:observation_type].to_s.presence
    return observations unless ot

    allowed = %w[kudos feedback quick_note generic]
    return observations unless allowed.include?(ot)

    observations.where(observation_type: ot)
  end

  def filter_by_soft_deleted_status(observations)
    # If param is not present or false: explicitly exclude soft-deleted
    # If param is true: do not add exclusion (allow both soft-deleted and non-soft-deleted)
    include_soft_deleted = params[:include_soft_deleted].present? && 
                          (params[:include_soft_deleted] == 'true' || params[:include_soft_deleted] == true)
    
    unless include_soft_deleted
      observations = observations.where(deleted_at: nil)
    end
    
    observations
  end

  private

  def apply_sort(observations)
    case params[:sort]
    when 'observed_at_asc'
      observations.order(observed_at: :asc)
    when 'ratings_count_desc'
      # Sort by count of observation_ratings, requires left join and group
      observations.left_joins(:observation_ratings)
                  .group('observations.id')
                  .order('COUNT(observation_ratings.id) DESC, observations.observed_at DESC')
    when 'story_asc'
      observations.order(story: :asc)
    else # 'observed_at_desc' or default
      observations.order(observed_at: :desc)
    end
  end
end

