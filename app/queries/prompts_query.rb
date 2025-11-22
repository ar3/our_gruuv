class PromptsQuery
  attr_reader :organization, :params, :current_person

  def initialize(organization, params = {}, current_person: nil)
    @organization = organization
    @params = params
    @current_person = current_person
  end

  def call
    prompts = base_scope
    prompts = filter_by_template(prompts)
    prompts = filter_by_status(prompts)
    prompts = filter_by_teammate(prompts)
    prompts = apply_sort(prompts)
    prompts
  end

  def current_filters
    filters = {}
    filters[:template] = params[:template] if params[:template].present?
    filters[:status] = params[:status] if params[:status].present? && params[:status] != 'all'
    filters[:teammate] = params[:teammate] if params[:teammate].present?
    filters
  end

  def current_sort
    params[:sort] || 'created_at_desc'
  end

  def current_view
    return params[:view] unless params[:view].blank?
    return params[:viewStyle] unless params[:viewStyle].blank?
    'table'
  end

  def current_spotlight
    params[:spotlight] || 'overview'
  end

  def has_active_filters?
    current_filters.any?
  end

  def base_scope
    @base_scope ||= begin
      # Use policy scope to get all prompts user has access to
      return Prompt.none unless current_teammate
      
      pundit_user = OpenStruct.new(user: current_teammate, impersonating_teammate: nil)
      policy = PromptPolicy::Scope.new(pundit_user, Prompt)
      policy.resolve
    end
  end

  def filter_by_template(prompts)
    return prompts unless params[:template].present?
    prompts.where(prompt_template_id: params[:template])
  end

  def filter_by_status(prompts)
    return prompts unless params[:status].present?
    
    case params[:status]
    when 'open'
      prompts.open
    when 'closed'
      prompts.closed
    else
      prompts
    end
  end

  def filter_by_teammate(prompts)
    return prompts unless params[:teammate].present?
    prompts.where(company_teammate_id: params[:teammate])
  end

  def apply_sort(prompts)
    case current_sort
    when 'created_at_desc'
      prompts.order(created_at: :desc)
    when 'created_at_asc'
      prompts.order(created_at: :asc)
    when 'updated_at_desc'
      prompts.order(updated_at: :desc)
    when 'updated_at_asc'
      prompts.order(updated_at: :asc)
    when 'template_title'
      prompts.joins(:prompt_template).order('prompt_templates.title ASC')
    when 'template_title_desc'
      prompts.joins(:prompt_template).order('prompt_templates.title DESC')
    else
      prompts.order(created_at: :desc)
    end
  end

  private

  def current_teammate
    return nil unless @current_person
    @current_teammate ||= @current_person.teammates.find_by(organization: organization)
  end
end

