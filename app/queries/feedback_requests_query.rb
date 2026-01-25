class FeedbackRequestsQuery
  attr_reader :organization, :params, :current_person

  def initialize(organization, params = {}, current_person: nil)
    @organization = organization
    @params = params
    @current_person = current_person
  end

  def call
    feedback_requests = base_scope
    feedback_requests = filter_by_archived(feedback_requests)
    feedback_requests = filter_by_subject(feedback_requests)
    feedback_requests = filter_by_requestor(feedback_requests)
    feedback_requests = filter_by_rateable(feedback_requests)
    feedback_requests = apply_sort(feedback_requests)
    feedback_requests
  end

  def current_filters
    filters = {}
    filters[:show_archived] = params[:show_archived] if params[:show_archived] == '1'
    filters[:subject] = params[:subject] if params[:subject].present?
    filters[:requestor] = params[:requestor] if params[:requestor].present?
    filters[:rateable_type] = params[:rateable_type] if params[:rateable_type].present?
    filters[:rateable_id] = params[:rateable_id] if params[:rateable_id].present?
    filters
  end

  def current_sort
    params[:sort] || 'created_at_desc'
  end

  def current_view
    params[:view] || 'table'
  end

  def current_spotlight
    params[:spotlight] || 'overview'
  end

  def has_active_filters?
    current_filters.any?
  end

  def base_scope
    @base_scope ||= begin
      return FeedbackRequest.none unless current_teammate
      
      company = organization.root_company || organization
      # Use policy scope to get all feedback requests user has access to
      pundit_user = OpenStruct.new(user: current_teammate, impersonating_teammate: nil)
      policy = FeedbackRequestPolicy::Scope.new(pundit_user, FeedbackRequest)
      policy.resolve.where(company: company)
    end
  end

  def filter_by_archived(feedback_requests)
    if params[:show_archived] == '1'
      feedback_requests
    else
      feedback_requests.not_deleted
    end
  end

  def filter_by_subject(feedback_requests)
    return feedback_requests unless params[:subject].present?
    feedback_requests.where(subject_of_feedback_teammate_id: params[:subject])
  end

  def filter_by_requestor(feedback_requests)
    return feedback_requests unless params[:requestor].present?
    feedback_requests.where(requestor_teammate_id: params[:requestor])
  end

  def filter_by_rateable(feedback_requests)
    return feedback_requests unless params[:rateable_type].present? && params[:rateable_id].present?
    feedback_requests.joins(:feedback_request_questions)
                     .where(feedback_request_questions: { rateable_type: params[:rateable_type], rateable_id: params[:rateable_id] })
                     .distinct
  end

  def apply_sort(feedback_requests)
    case current_sort
    when 'created_at_desc'
      feedback_requests.order(created_at: :desc)
    when 'created_at_asc'
      feedback_requests.order(created_at: :asc)
    when 'updated_at_desc'
      feedback_requests.order(updated_at: :desc)
    when 'updated_at_asc'
      feedback_requests.order(updated_at: :asc)
    when 'subject_name'
      feedback_requests.joins(subject_of_feedback_teammate: :person).order('people.last_name ASC, people.first_name ASC')
    when 'subject_name_desc'
      feedback_requests.joins(subject_of_feedback_teammate: :person).order('people.last_name DESC, people.first_name DESC')
    else
      feedback_requests.order(created_at: :desc)
    end
  end

  private

  def current_teammate
    return nil unless @current_person
    @current_teammate ||= @current_person.teammates.find_by(organization: organization)
  end
end
