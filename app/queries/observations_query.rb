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
    
    observations.where(observer_id: params[:observer_id])
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

