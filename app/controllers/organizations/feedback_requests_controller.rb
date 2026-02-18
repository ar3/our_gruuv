class Organizations::FeedbackRequestsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_feedback_request, only: [:show, :edit, :update, :destroy, :select_focus, :update_focus, :feedback_prompt, :update_questions, :select_respondents, :update_respondents, :add_respondent, :remove_respondent, :answer, :submit_answers, :notify_respondents, :archive, :restore]

  after_action :verify_authorized
  after_action :verify_policy_scoped, only: [:index, :as_subject, :requested_for_others]

  def index
    authorize company, :view_feedback_requests?
    base_scope = policy_scope(FeedbackRequest).where(company: company)

    # Tab: I'm the Respondent — requests where I'm a respondent
    @requests_of_me = if current_company_teammate
      scope = base_scope
        .joins(:feedback_request_responders)
        .where(feedback_request_responders: { teammate_id: current_company_teammate.id })
        .order(created_at: :desc)
        .includes(:requestor_teammate, :subject_of_feedback_teammate, :feedback_request_responders)
        .distinct
      if params[:requests_of_me] == 'all'
        scope.where("feedback_requests.deleted_at IS NULL OR feedback_request_responders.completed_at IS NOT NULL")
      else
        scope.where(feedback_request_responders: { completed_at: nil }).where(feedback_requests: { deleted_at: nil })
      end
    else
      FeedbackRequest.none
    end
    @requests_of_me_filter = params[:requests_of_me] == 'all' ? 'all' : 'open'

    set_feedback_request_tab_counts(base_scope)
    @active_feedback_tab = :respondent
  end

  def as_subject
    authorize company, :view_feedback_requests?
    base_scope = policy_scope(FeedbackRequest).where(company: company)
    load_feedback_requests_for_tab(
      base_scope.where(subject_of_feedback_teammate_id: current_company_teammate&.id)
    )
    set_feedback_request_tab_counts(base_scope)
    @active_feedback_tab = :as_subject
  end

  def requested_for_others
    authorize company, :view_feedback_requests?
    base_scope = policy_scope(FeedbackRequest).where(company: company)
    my_id = current_company_teammate&.id
    creator_not_subject_scope = base_scope
      .where(requestor_teammate_id: my_id)
      .where.not(subject_of_feedback_teammate_id: my_id)
    load_feedback_requests_for_tab(creator_not_subject_scope)
    set_feedback_request_tab_counts(base_scope)
    @active_feedback_tab = :requested_for_others
  end

  def show
    authorize @feedback_request

    @questions = @feedback_request.feedback_request_questions.ordered.includes(:rateable)
    @responders = @feedback_request.responders.includes(:person)
    @observations = @feedback_request.observations.includes(:observer, :observed_teammates)
    @responder_records_by_teammate_id = @feedback_request.feedback_request_responders.index_by(&:teammate_id)
    @observations_by_observer_id = @feedback_request.observations.includes(:feedback_request_question).group_by(&:observer_id)
    @observation_by_observer_and_question = @feedback_request.observations.includes(:feedback_request_question).index_by { |o| [o.observer_id, o.feedback_request_question_id] }

    @notifications_sent = @feedback_request.respondent_notifications_sent
    teammate_ids = @notifications_sent.filter_map { |n| n.metadata&.dig('teammate_id') }.uniq.map(&:to_i)
    @teammates_by_id = CompanyTeammate.where(id: teammate_ids).includes(:person).index_by(&:id)
  end

  def new
    @feedback_request = FeedbackRequest.new(company: company)
    authorize @feedback_request
    
    # Load eligible teammates for subject selection (with department for optgroups)
    @teammates = eligible_subjects_for_feedback_request
                  .includes(:person, employment_tenures: { seat: { title: :department } })
    @teammates_grouped_for_select = teammates_grouped_by_department_for_select(@teammates, company)
  end

  def create
    @feedback_request = FeedbackRequest.new(feedback_request_params)
    @feedback_request.company = company
    @feedback_request.requestor_teammate = current_company_teammate
    
    # Ensure subject_of_feedback_teammate association is loaded for authorization
    if @feedback_request.subject_of_feedback_teammate_id.present?
      subject_teammate = CompanyTeammate.find_by(id: @feedback_request.subject_of_feedback_teammate_id, organization: company)
      if subject_teammate
        @feedback_request.subject_of_feedback_teammate = subject_teammate
        @feedback_request.association(:subject_of_feedback_teammate).target = subject_teammate
      end
    end
    authorize @feedback_request
    
    if @feedback_request.save
      redirect_to select_focus_organization_feedback_request_path(organization, @feedback_request)
    else
      @teammates = eligible_subjects_for_feedback_request
                    .includes(:person, employment_tenures: { seat: { title: :department } })
      @teammates_grouped_for_select = teammates_grouped_by_department_for_select(@teammates, company)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @feedback_request
    
    unless @feedback_request.can_be_edited?
      redirect_to organization_feedback_request_path(organization, @feedback_request),
                  alert: 'This feedback request cannot be edited in its current state.'
      return
    end
    
    # Load eligible teammates for subject selection (with department for optgroups)
    @teammates = eligible_subjects_for_feedback_request
                  .includes(:person, employment_tenures: { seat: { title: :department } })
    @teammates_grouped_for_select = teammates_grouped_by_department_for_select(@teammates, company)
  end

  def update
    authorize @feedback_request
    
    unless @feedback_request.can_be_edited?
      redirect_to organization_feedback_request_path(organization, @feedback_request),
                  alert: 'This feedback request cannot be edited in its current state.'
      return
    end
    
    if @feedback_request.update(feedback_request_params)
      # Redirect to appropriate step based on current state
      if @feedback_request.feedback_request_questions.empty?
        redirect_to select_focus_organization_feedback_request_path(organization, @feedback_request)
      elsif @feedback_request.feedback_request_questions.any? { |q| q.question_text.blank? }
        redirect_to feedback_prompt_organization_feedback_request_path(organization, @feedback_request)
      elsif @feedback_request.responders.empty?
        redirect_to select_respondents_organization_feedback_request_path(organization, @feedback_request)
      else
        @feedback_request.validate_state!
        redirect_to organization_feedback_request_path(organization, @feedback_request),
                    notice: 'Feedback request was successfully updated.'
      end
    else
      @teammates = eligible_subjects_for_feedback_request
                    .includes(:person, employment_tenures: { seat: { title: :department } })
      @teammates_grouped_for_select = teammates_grouped_by_department_for_select(@teammates, company)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @feedback_request
    
    @feedback_request.soft_delete!
    redirect_to organization_feedback_requests_path(organization),
                notice: 'Feedback request was successfully archived.'
  end

  def archive
    authorize @feedback_request, :destroy?
    
    @feedback_request.soft_delete!
    redirect_to organization_feedback_request_path(organization, @feedback_request),
                notice: 'Feedback request was successfully archived.'
  end

  def restore
    authorize @feedback_request, :update?
    
    @feedback_request.restore!
    # State is now computed, so no need to update it
    redirect_to organization_feedback_request_path(organization, @feedback_request),
                notice: 'Feedback request was successfully restored.'
  end

  def notify_respondents
    authorize @feedback_request, :update?

    unless organization.slack_configured?
      redirect_to organization_feedback_request_path(organization, @feedback_request),
                  alert: 'Slack is not configured for this organization.'
      return
    end

    if @feedback_request.responders.empty?
      redirect_to organization_feedback_request_path(organization, @feedback_request),
                  alert: 'There are no respondents to notify.'
      return
    end

    result = FeedbackRequests::NotifyRespondentsService.call(feedback_request: @feedback_request)

    if result.ok?
      message = result.value[:sent].positive? ? "Slack notification sent to #{result.value[:sent]} respondent(s)." : 'No respondents have Slack connected; no notifications were sent.'
      redirect_to organization_feedback_request_path(organization, @feedback_request), notice: message
    else
      redirect_to organization_feedback_request_path(organization, @feedback_request),
                  alert: "Failed to send some notifications: #{result.error}"
    end
  end

  def select_focus
    authorize @feedback_request, :update?

    @subject_teammate = @feedback_request.subject_of_feedback_teammate
    @active_tenure = @subject_teammate.active_employment_tenure if @subject_teammate.is_a?(CompanyTeammate)
    @active_position = @active_tenure&.position
    
    # Get position checkbox data
    @position = @active_position
    
    # Get assignments: active tenures + required assignments for active position
    assignment_ids = Set.new
    if @subject_teammate
      # All assignment tenures where subject has ever had an active assignment tenure (anticipated_energy_percentage > 0)
      @subject_teammate.assignment_tenures
        .joins(:assignment)
        .where(assignments: { company: company.self_and_descendants })
        .where('anticipated_energy_percentage > ?', 0)
        .pluck(:assignment_id)
        .each { |id| assignment_ids.add(id) }
      
      # Required assignments for active position
      if @active_position
        @active_position.required_assignments.pluck(:assignment_id).each { |id| assignment_ids.add(id) }
      end
    end
    @assignments = Assignment.unarchived.where(id: assignment_ids.to_a, company: company.self_and_descendants).ordered
    
    # Get abilities required for all assignments above
    ability_ids = Set.new
    @assignments.each do |assignment|
      assignment.assignment_abilities.pluck(:ability_id).each { |id| ability_ids.add(id) }
    end
    @abilities = Ability.unarchived.where(id: ability_ids.to_a, company: company).order(:name)
    
    # Get aspirations: company + department aspirations from position's title department and departments between title and company
    aspiration_org_ids = [company.id]
    if @active_position&.title&.department
      # Get all departments from title's department up the department hierarchy
      current_dept = @active_position.title.department
      while current_dept
        aspiration_org_ids << current_dept.id
        current_dept = current_dept.parent_department
      end
    end
    @aspirations = Aspiration.where(company: company).ordered
    
    # Load currently selected focus items
    @selected_position = @feedback_request.feedback_request_questions.find_by(rateable_type: 'Position')&.rateable
    @selected_assignments = @feedback_request.feedback_request_questions.where(rateable_type: 'Assignment').map(&:rateable).compact
    @selected_abilities = @feedback_request.feedback_request_questions.where(rateable_type: 'Ability').map(&:rateable).compact
    @selected_aspirations = @feedback_request.feedback_request_questions.where(rateable_type: 'Aspiration').map(&:rateable).compact
  end

  def update_focus
    authorize @feedback_request, :update?

    unless @feedback_request.can_be_edited?
      redirect_to organization_feedback_request_path(organization, @feedback_request),
                  alert: 'This feedback request cannot be edited in its current state.'
      return
    end

    # Clear existing questions
    @feedback_request.feedback_request_questions.destroy_all
    
    # Build questions from selected focus items
    position = nil
    if params[:position_id].present?
      subject_teammate = @feedback_request.subject_of_feedback_teammate
      if subject_teammate.is_a?(CompanyTeammate)
        active_tenure = subject_teammate.active_employment_tenure
        active_position = active_tenure&.position
        if active_position && active_position.id.to_s == params[:position_id].to_s
          position = active_position
        end
      end
    end
    
    assignment_ids = Array(params[:assignment_ids]).map(&:to_i).reject(&:zero?)
    ability_ids = Array(params[:ability_ids]).map(&:to_i).reject(&:zero?)
    aspiration_ids = Array(params[:aspiration_ids]).map(&:to_i).reject(&:zero?)
    
    # Create placeholder questions (will be filled in feedback_prompt)
    position_attr = { rateable_type: 'Position', rateable_id: position.id } if position
    assignment_attrs = Assignment.unarchived.where(id: assignment_ids, company: company.self_and_descendants).map { |a| { rateable_type: 'Assignment', rateable_id: a.id } }
    ability_attrs = Ability.unarchived.where(id: ability_ids, company: company).map { |a| { rateable_type: 'Ability', rateable_id: a.id } }
    aspiration_attrs = Aspiration.where(id: aspiration_ids, company: company).map { |a| { rateable_type: 'Aspiration', rateable_id: a.id } }
    
    all_focus_items = [position_attr].compact + assignment_attrs + ability_attrs + aspiration_attrs

    if all_focus_items.empty?
      # State will be computed as invalid automatically
      redirect_to select_focus_organization_feedback_request_path(organization, @feedback_request),
                  alert: 'Please select at least one focus item.'
      return
    end

    all_focus_items.each_with_index do |item, index|
      @feedback_request.feedback_request_questions.create!(
        question_text: '', # Will be filled in feedback_prompt
        position: index + 1,
        rateable_type: item[:rateable_type],
        rateable_id: item[:rateable_id]
      )
    end

    redirect_to feedback_prompt_organization_feedback_request_path(organization, @feedback_request)
  end

  def feedback_prompt
    authorize @feedback_request, :update?
    
    @questions = @feedback_request.feedback_request_questions.ordered.includes(:rateable)
    
    render :feedback_prompt
  end

  def update_questions
    authorize @feedback_request, :update?
    
    questions_params = params[:questions] || {}
    all_valid = true
    
    @feedback_request.feedback_request_questions.ordered.each do |question|
      question_text = questions_params[question.id.to_s]&.dig(:question_text)
      if question_text.blank?
        all_valid = false
        next
      end
      question.update!(question_text: question_text)
    end
    
    if !all_valid || @feedback_request.feedback_request_questions.any? { |q| q.question_text.blank? }
      # State will be computed as invalid automatically
      redirect_to feedback_prompt_organization_feedback_request_path(organization, @feedback_request),
                  alert: 'All questions must have text.'
      return
    end
    
    redirect_to select_respondents_organization_feedback_request_path(organization, @feedback_request)
  end

  def select_respondents
    authorize @feedback_request, :update?

    # All active teammates, sorted by last name, preferred name, first name
    all_teammates = CompanyTeammate
      .where(organization: company)
      .where(last_terminated_at: nil)
      .joins(:person)
      .includes(:person, employment_tenures: { position: { title: :department } })
      .order(Arel.sql('people.last_name ASC NULLS LAST, people.preferred_name ASC NULLS LAST, people.first_name ASC NULLS LAST'))

    # Group by department (from active employment tenure's position title)
    teammates_by_department = {}
    all_teammates.each do |t|
      tenure = t.employment_tenures.detect { |et| et.ended_at.nil? && et.company_id == company.id }
      dept = tenure&.position&.title&.department
      teammates_by_department[dept] ||= []
      teammates_by_department[dept] << t
    end
    teammates_by_department.each_value do |list|
      list.sort_by! { |t| [t.person.last_name.to_s, t.person.preferred_name.to_s, t.person.first_name.to_s] }
    end

    selected_ids = @feedback_request.responders.pluck(:id).to_set
    @selected_respondent_teammates = @feedback_request.responders
      .joins(:person)
      .includes(:person)
      .order(Arel.sql('people.last_name ASC NULLS LAST, people.preferred_name ASC NULLS LAST, people.first_name ASC NULLS LAST'))

    # Grouped options for dropdown: only teammates not already in the list
    teammates_by_department.each_key do |dept|
      teammates_by_department[dept] = teammates_by_department[dept].reject { |t| selected_ids.include?(t.id) }
    end
    teammates_by_department.delete_if { |_, list| list.empty? }

    @grouped_respondent_options = teammates_by_department.keys
      .sort_by { |dept| dept.nil? ? [1, ''] : [0, dept.display_name] }
      .map do |dept|
        label = dept ? dept.display_name : 'No department'
        options = teammates_by_department[dept].map { |t| [t.person.display_name, t.id] }
        [label, options]
      end

    render :select_respondents
  end

  def add_respondent
    authorize @feedback_request, :update?
    unless @feedback_request.can_be_edited? || @feedback_request.can_add_responders?
      redirect_to organization_feedback_request_path(organization, @feedback_request), alert: 'This feedback request cannot be edited.'
      return
    end

    teammate_id = params[:respondent_id].to_i
    if teammate_id.zero?
      redirect_to select_respondents_organization_feedback_request_path(organization, @feedback_request), alert: 'Please select a teammate to add.'
      return
    end

    unless CompanyTeammate.exists?(id: teammate_id, organization: company)
      redirect_to select_respondents_organization_feedback_request_path(organization, @feedback_request), alert: 'Invalid teammate.'
      return
    end

    if @feedback_request.responders.exists?(id: teammate_id)
      redirect_to select_respondents_organization_feedback_request_path(organization, @feedback_request)
      return
    end

    @feedback_request.feedback_request_responders.create!(teammate_id: teammate_id)
    redirect_to select_respondents_organization_feedback_request_path(organization, @feedback_request)
  end

  def remove_respondent
    authorize @feedback_request, :update?
    unless @feedback_request.can_be_edited? || @feedback_request.can_add_responders?
      redirect_to organization_feedback_request_path(organization, @feedback_request), alert: 'This feedback request cannot be edited.'
      return
    end

    teammate_id = params[:respondent_id].to_i
    if teammate_id.zero?
      redirect_to select_respondents_organization_feedback_request_path(organization, @feedback_request)
      return
    end

    @feedback_request.feedback_request_responders.where(teammate_id: teammate_id).destroy_all
    redirect_to select_respondents_organization_feedback_request_path(organization, @feedback_request)
  end

  def update_respondents
    authorize @feedback_request, :update?

    unless @feedback_request.can_be_edited? || @feedback_request.can_add_responders?
      redirect_to organization_feedback_request_path(organization, @feedback_request),
                  alert: 'This feedback request cannot be edited in its current state.'
      return
    end

    # Respondents are managed via add_respondent/remove_respondent; this action finalizes the list
    if @feedback_request.responders.empty?
      redirect_to select_respondents_organization_feedback_request_path(organization, @feedback_request),
                  alert: 'Please select at least one respondent.'
      return
    end

    redirect_to organization_feedback_request_path(organization, @feedback_request),
                notice: 'Feedback request was successfully created.'
  end

  def answer
    authorize @feedback_request, :answer?
    if @feedback_request.archived?
      redirect_to organization_feedback_requests_path(organization),
                  notice: 'This feedback request has been archived and is no longer accepting responses.'
      return
    end

    @questions = @feedback_request.feedback_request_questions.ordered.includes(:rateable)
    # Existing observations from this responder, keyed by question id (for prefilling and observation link)
    @observation_by_question_id = @feedback_request.observations
      .where(observer: current_person)
      .includes(:observation_ratings)
      .index_by(&:feedback_request_question_id)
    
    # Load resources for optional ratings (for questions without rateable)
    @assignments = company.assignments.ordered
    @abilities = company.abilities.order(:name)
    @aspirations = company.aspirations.ordered
  end

  def submit_answers
    authorize @feedback_request, :answer?
    
    answers = params[:answers] || {}
    privacy_level = params[:privacy_level] || 'observed_and_managers'
    complete = params[:save_and_complete].present?
    
    result = FeedbackRequests::AnswerService.call(
      feedback_request: @feedback_request,
      answers: answers,
      responder_teammate: current_company_teammate,
      privacy_level: privacy_level,
      complete: complete
    )
    
    if result.ok?
      responder_record = @feedback_request.feedback_request_responders.find_by(teammate_id: current_company_teammate.id)
      if responder_record
        responder_record.update!(completed_at: complete ? Time.current : nil)
      end

      redirect_path = policy(@feedback_request).show? ? organization_feedback_request_path(organization, @feedback_request) : organization_feedback_requests_path(organization)
      notice = complete ? 'Your feedback has been submitted and marked complete.' : 'Your feedback has been saved and kept incomplete.'
      redirect_to redirect_path, notice: notice
    else
      @questions = @feedback_request.feedback_request_questions.ordered.includes(:rateable)
      @observation_by_question_id = @feedback_request.observations
        .where(observer: current_person)
        .includes(:observation_ratings)
        .index_by(&:feedback_request_question_id)
      @assignments = company.assignments.ordered
      @abilities = company.abilities.order(:name)
      @aspirations = company.aspirations.ordered
      
      flash[:alert] = result.error
      render :answer, status: :unprocessable_entity
    end
  end

  private

  def set_feedback_request_tab_counts(base_scope)
    unless current_company_teammate
      @incomplete_respondent_count = @as_subject_count = @requested_for_others_count = 0
      return
    end
    my_id = current_company_teammate.id
    # Incomplete where I'm the respondent (open requests where I haven't completed)
    @incomplete_respondent_count = base_scope
      .joins(:feedback_request_responders)
      .where(feedback_request_responders: { teammate_id: my_id, completed_at: nil })
      .where(feedback_requests: { deleted_at: nil })
      .distinct
      .count
    # Unarchived where I'm the subject
    @as_subject_count = base_scope
      .where(subject_of_feedback_teammate_id: my_id)
      .where(deleted_at: nil)
      .count
    # Unarchived where I'm the creator but not the subject
    @requested_for_others_count = base_scope
      .where(requestor_teammate_id: my_id)
      .where.not(subject_of_feedback_teammate_id: my_id)
      .where(deleted_at: nil)
      .count
  end

  def load_feedback_requests_for_tab(scope)
    query = FeedbackRequestsQuery.new(organization, params, current_person: current_person)
    @feedback_requests = query.filter_by_archived(scope)
    @feedback_requests = query.filter_by_subject(@feedback_requests)
    @feedback_requests = query.filter_by_requestor(@feedback_requests)
    @feedback_requests = query.filter_by_rateable(@feedback_requests)
    @feedback_requests = query.apply_sort(@feedback_requests)
    @feedback_requests = @feedback_requests.includes(
      :requestor_teammate,
      :subject_of_feedback_teammate,
      { feedback_request_questions: [] },
      :responders
    )
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @current_spotlight = query.current_spotlight
    @spotlight_stats = calculate_spotlight_stats(requests_scope: @feedback_requests)
  end

  def calculate_spotlight_stats(requests_scope: nil)
    all_requests = if requests_scope
      requests_scope
    else
      base = FeedbackRequestsQuery.new(organization, params.except(:sort), current_person: current_person).call
      current_company_teammate ? base.where(requestor_teammate_id: current_company_teammate.id) : base.none
    end
    open_requests_scope = all_requests.respond_to?(:not_deleted) ? all_requests.not_deleted : all_requests.where(deleted_at: nil)

    case @current_spotlight
    when 'open_requests'
      open_requests = open_requests_scope
      open_list = open_requests.to_a
      {
        open_requests: open_requests.count,
        total_requests: all_requests.count,
        with_responses: open_list.count { |r| r.has_responses? },
        without_responses: open_list.count { |r| !r.has_responses? }
      }
    when 'open_responders'
      open_requests = open_requests_scope
      open_list = open_requests.includes(:responders).to_a
      total_responders = open_list.sum { |r| r.responders.count }
      responded_count = open_list.sum { |r| r.responder_response_count }
      unanswered_count = total_responders - responded_count
      {
        total_responders: total_responders,
        responded_count: responded_count,
        unanswered_count: unanswered_count,
        open_requests: open_requests.count
      }
    when 'responder_count'
      open_requests = open_requests_scope
      open_list = open_requests.includes(:responders).to_a
      {
        total_responders: open_list.sum { |r| r.responders.count },
        responded_count: open_list.sum { |r| r.responder_response_count },
        open_requests: open_requests.count
      }
    else # 'overview'
      open_requests = open_requests_scope
      open_list = open_requests.includes(:responders).to_a
      {
        open_requests: open_requests.count,
        total_requests: all_requests.count,
        with_responses: open_list.count { |r| r.has_responses? },
        total_responders: open_list.sum { |r| r.responders.count },
        responded_count: open_list.sum { |r| r.responder_response_count }
      }
    end
  end

  def set_feedback_request
    @feedback_request = FeedbackRequest.find(params[:id])
  end

  def feedback_request_params
    params.require(:feedback_request).permit(
      :subject_of_feedback_teammate_id,
      :subject_line
    )
  end

  def process_questions_update(questions_attributes)
    # Handle question updates, creates, and deletes
    questions_attributes.each do |key, attrs|
      if attrs[:_destroy] == '1' || attrs['_destroy'] == '1'
        # Delete question
        question = @feedback_request.feedback_request_questions.find_by(id: attrs[:id] || attrs['id'])
        question&.destroy
      elsif attrs[:id].present? || attrs['id'].present?
        # Update existing question
        question = @feedback_request.feedback_request_questions.find(attrs[:id] || attrs['id'])
        question.update(
          question_text: attrs[:question_text] || attrs['question_text'],
          position: attrs[:position] || attrs['position'],
          rateable_type: attrs[:rateable_type].presence || attrs['rateable_type'].presence,
          rateable_id: attrs[:rateable_id].presence || attrs['rateable_id'].presence
        )
      else
        # Create new question
        @feedback_request.feedback_request_questions.create(
          question_text: attrs[:question_text] || attrs['question_text'],
          position: attrs[:position] || attrs['position'],
          rateable_type: attrs[:rateable_type].presence || attrs['rateable_type'].presence,
          rateable_id: attrs[:rateable_id].presence || attrs['rateable_id'].presence
        )
      end
    end
  end

  def update_responders(responder_teammate_ids)
    # Remove responders not in the list
    current_ids = @feedback_request.feedback_request_responders.pluck(:teammate_id).map(&:to_s)
    ids_to_remove = current_ids - responder_teammate_ids.map(&:to_s)
    @feedback_request.feedback_request_responders.where(teammate_id: ids_to_remove).destroy_all
    
    # Add new responders
    new_ids = responder_teammate_ids.map(&:to_s) - current_ids
    new_ids.each do |teammate_id|
      @feedback_request.feedback_request_responders.create(teammate_id: teammate_id)
    end
  end

  def eligible_subjects_for_feedback_request
    viewing_teammate = current_company_teammate
    return CompanyTeammate.none unless viewing_teammate
    
    # If user has can_manage_employment, they can request feedback from any active company teammate
    if viewing_teammate.can_manage_employment?
      return CompanyTeammate.where(organization: company)
                            .where(last_terminated_at: nil)
                            .includes(:person)
                            .order('people.last_name, people.first_name')
    end
    
    # Otherwise, only viewing teammate + all teammates in their hierarchy (direct and indirect reports)
    eligible_teammate_ids = Set.new
    
    # Always include viewing teammate themselves
    eligible_teammate_ids.add(viewing_teammate.id)
    
    # Get all direct and indirect reports using EmployeeHierarchyQuery
    hierarchy_query = EmployeeHierarchyQuery.new(person: viewing_teammate.person, organization: company)
    reports = hierarchy_query.call
    
    # Extract teammate IDs from reports
    report_person_ids = reports.map { |r| r[:person_id] }
    if report_person_ids.any?
      report_teammates = CompanyTeammate.where(organization: company, person_id: report_person_ids)
      eligible_teammate_ids.merge(report_teammates.pluck(:id))
    end
    
    # Return teammates sorted by last name, then first name
    CompanyTeammate.where(id: eligible_teammate_ids.to_a)
                   .where(last_terminated_at: nil)
                   .includes(:person)
                   .order('people.last_name, people.first_name')
  end

  # Build grouped options for subject dropdown: optgroups by department, sorted by department
  # then within each group by last_name, preferred_name, first_name.
  def teammates_grouped_by_department_for_select(teammates, org_company)
    list = teammates.respond_to?(:to_a) ? teammates.to_a : teammates
    by_dept = list.group_by do |t|
      tenure = t.employment_tenures.select { |et| et.ended_at.nil? && et.company_id == org_company.id }.first
      tenure&.seat&.title&.department
    end
    # Sort department groups: "No department" first, then by department display_name
    sorted_depts = by_dept.keys.sort_by { |d| d.nil? ? '' : d.display_name }
    sorted_depts.map do |dept|
      teammates_in_dept = by_dept[dept].sort_by do |t|
        p = t.person
        [p.last_name.to_s, p.preferred_name.to_s, p.first_name.to_s]
      end
      label = dept.nil? ? 'No department' : dept.display_name
      [label, teammates_in_dept.map { |t| [t.person.display_name, t.id] }]
    end
  end
end
