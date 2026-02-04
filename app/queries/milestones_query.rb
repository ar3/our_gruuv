class MilestonesQuery
  attr_reader :organization, :params, :current_person

  def initialize(organization, params = {}, current_person: nil)
    @organization = organization
    @params = params
    @current_person = current_person
  end

  def call
    milestones = base_scope
    milestones = filter_by_published(milestones)
    milestones = filter_by_timeframe(milestones)
    milestones = filter_by_ability(milestones)
    milestones = filter_by_milestone_level(milestones)
    milestones = filter_by_person(milestones)
    milestones = apply_sort(milestones)
    milestones
  end

  def current_filters
    filters = {}
    filters[:privacy] = params[:privacy] if params[:privacy].present?
    filters[:timeframe] = params[:timeframe] if params[:timeframe].present? && params[:timeframe] != 'all'
    if params[:timeframe] == 'between'
      filters[:timeframe_start_date] = params[:timeframe_start_date] if params[:timeframe_start_date].present?
      filters[:timeframe_end_date] = params[:timeframe_end_date] if params[:timeframe_end_date].present?
    end
    filters[:ability] = params[:ability] if params[:ability].present?
    filters[:milestone_level] = params[:milestone_level] if params[:milestone_level].present?
    filters[:person] = params[:person] if params[:person].present?
    filters
  end

  def current_sort
    params[:sort] || 'attained_at_desc'
  end

  def current_view
    return params[:view] unless params[:view].blank?
    return params[:viewStyle] unless params[:viewStyle].blank?
    'wall_badge' # Default to badge wall style
  end

  def current_spotlight
    params[:spotlight] || 'overview'
  end

  def has_active_filters?
    current_filters.any?
  end

  private

  def base_scope
    TeammateMilestone.joins(:ability, :company_teammate, :certifying_teammate)
                     .where(abilities: { company_id: @organization.id })
                     .includes(:ability, :company_teammate, certifying_teammate: :person)
  end

  def filter_by_published(milestones)
    case params[:privacy]
    when 'published'
      milestones.published
    when 'private'
      milestones.unpublished
    else
      # Default: only show published milestones on celebration page
      milestones.published
    end
  end

  def filter_by_timeframe(milestones)
    timeframe = params[:timeframe] || 'all'
    
    case timeframe
    when 'today'
      milestones.where(attained_at: Date.current)
    when 'this_week'
      milestones.where(attained_at: 1.week.ago..Time.current)
    when 'this_month'
      milestones.where(attained_at: 1.month.ago..Time.current)
    when 'last_30_days'
      milestones.where(attained_at: 30.days.ago..Time.current)
    when 'last_90_days'
      milestones.where(attained_at: 90.days.ago..Time.current)
    when 'this_year'
      milestones.where(attained_at: Date.current.beginning_of_year..Time.current)
    when 'between'
      start_date = params[:timeframe_start_date].present? ? Date.parse(params[:timeframe_start_date]) : nil
      end_date = params[:timeframe_end_date].present? ? Date.parse(params[:timeframe_end_date]) : nil
      if start_date && end_date
        milestones.where(attained_at: start_date..end_date)
      else
        milestones
      end
    else
      milestones
    end
  end

  def filter_by_ability(milestones)
    return milestones unless params[:ability].present?
    milestones.where(abilities: { id: params[:ability] })
  end

  def filter_by_milestone_level(milestones)
    return milestones unless params[:milestone_level].present?
    milestones.where(milestone_level: params[:milestone_level])
  end

  def filter_by_person(milestones)
    return milestones unless params[:person].present?
    milestones.joins(company_teammate: :person).where(people: { id: params[:person] })
  end

  def apply_sort(milestones)
    sort = current_sort
    
    case sort
    when 'attained_at_desc'
      milestones.order(attained_at: :desc)
    when 'attained_at_asc'
      milestones.order(attained_at: :asc)
    when 'person_name_asc'
      milestones.joins(company_teammate: :person).order('people.last_name ASC, people.first_name ASC')
    when 'person_name_desc'
      milestones.joins(company_teammate: :person).order('people.last_name DESC, people.first_name DESC')
    when 'ability_name_asc'
      milestones.joins(:ability).order('abilities.name ASC')
    when 'ability_name_desc'
      milestones.joins(:ability).order('abilities.name DESC')
    when 'milestone_level_desc'
      milestones.order(milestone_level: :desc, attained_at: :desc)
    when 'milestone_level_asc'
      milestones.order(milestone_level: :asc, attained_at: :desc)
    else
      milestones.order(attained_at: :desc)
    end
  end
end

