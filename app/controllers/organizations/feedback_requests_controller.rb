class Organizations::FeedbackRequestsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_feedback_request, only: [:show, :edit, :update, :destroy, :select_focus, :update_focus, :feedback_prompt, :update_questions, :select_respondents, :update_respondents, :answer, :submit_answers, :archive, :restore]

  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    authorize company, :view_feedback_requests?
    
    # Use query object to get filtered and sorted feedback requests
    query = FeedbackRequestsQuery.new(organization, params, current_person: current_person)
    
    # Get base scope using policy_scope (required by Pundit)
    base_scope = policy_scope(FeedbackRequest).where(company: company)
    
    # Apply filters from query object
    @feedback_requests = base_scope
    @feedback_requests = query.filter_by_archived(@feedback_requests)
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
    
    # Calculate spotlight statistics
    @spotlight_stats = calculate_spotlight_stats
  end

  def customize_view
    authorize company, :view_feedback_requests?
    
    # Load current state from params
    query = FeedbackRequestsQuery.new(organization, params, current_person: current_person)
    
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @current_spotlight = query.current_spotlight
    
    # Get available options for filters
    @available_subjects = CompanyTeammate.where(organization: company).where(last_terminated_at: nil).includes(:person).order('people.last_name, people.first_name')
    @available_requestors = CompanyTeammate.where(organization: company).where(last_terminated_at: nil).includes(:person).order('people.last_name, people.first_name')
    @available_assignments = company.assignments.ordered
    @available_abilities = company.abilities.order(:name)
    @available_aspirations = company.aspirations.ordered
    
    # Preserve current params for return URL
    return_params = params.except(:controller, :action, :page).permit!.to_h
    @return_url = organization_feedback_requests_path(organization, return_params)
    @return_text = "Back to Feedback Requests"
    
    render layout: 'overlay'
  end

  def update_view
    authorize company, :view_feedback_requests?
    
    # Build redirect URL with all view customization params
    redirect_params = params.except(:controller, :action, :authenticity_token, :_method, :commit).permit!.to_h
    
    redirect_to organization_feedback_requests_path(organization, redirect_params)
  end

  def show
    authorize @feedback_request
    
    @questions = @feedback_request.feedback_request_questions.ordered.includes(:rateable)
    @responders = @feedback_request.responders.includes(:person)
    @observations = @feedback_request.observations.includes(:observer, :observed_teammates)
  end

  def new
    @feedback_request = FeedbackRequest.new(company: company)
    authorize @feedback_request
    
    # Load eligible teammates for subject selection
    @teammates = eligible_subjects_for_feedback_request
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
    
    # Load eligible teammates for subject selection
    @teammates = eligible_subjects_for_feedback_request
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
    @assignments = Assignment.where(id: assignment_ids.to_a, company: company.self_and_descendants).ordered
    
    # Get abilities required for all assignments above
    ability_ids = Set.new
    @assignments.each do |assignment|
      assignment.assignment_abilities.pluck(:ability_id).each { |id| ability_ids.add(id) }
    end
    @abilities = Ability.where(id: ability_ids.to_a, company: company).order(:name)
    
    # Get aspirations: company + department aspirations from position's title department and departments between title and company
    aspiration_org_ids = [company.id]
    if @active_position&.title&.department
      # Get all departments from title's department up to company
      current_dept = @active_position.title.department
      while current_dept && current_dept != company
        aspiration_org_ids << current_dept.id
        current_dept = current_dept.parent
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
    assignment_attrs = Assignment.where(id: assignment_ids, company: company.self_and_descendants).map { |a| { rateable_type: 'Assignment', rateable_id: a.id } }
    ability_attrs = Ability.where(id: ability_ids, company: company).map { |a| { rateable_type: 'Ability', rateable_id: a.id } }
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
    
    @teammates = CompanyTeammate.where(organization: company).where(last_terminated_at: nil).includes(:person).order('people.last_name, people.first_name')
    @selected_respondents = @feedback_request.responders.pluck(:id)
    
    render :select_respondents
  end

  def update_respondents
    authorize @feedback_request, :update?
    
    unless @feedback_request.can_be_edited? || @feedback_request.can_add_responders?
      redirect_to organization_feedback_request_path(organization, @feedback_request),
                  alert: 'This feedback request cannot be edited in its current state.'
      return
    end
    
    responder_ids = Array(params[:respondent_ids]).map(&:to_i).reject(&:zero?)
    
    if responder_ids.empty? && @feedback_request.responders.empty?
      # State will be computed as invalid automatically
      redirect_to select_respondents_organization_feedback_request_path(organization, @feedback_request),
                  alert: 'Please select at least one respondent.'
      return
    end
    
    # Update responders (only add if active, replace if invalid/ready)
    if @feedback_request.active?
      # Only add new responders, don't remove existing
      current_ids = @feedback_request.responders.pluck(:id).map(&:to_i)
      new_ids = responder_ids - current_ids
      new_ids.each do |teammate_id|
        @feedback_request.feedback_request_responders.create(teammate_id: teammate_id)
      end
    else
      # Replace all responders
      update_responders(responder_ids)
    end
    
    # State is now computed, so no need to validate/update it
    redirect_to organization_feedback_request_path(organization, @feedback_request),
                notice: 'Feedback request was successfully created.'
  end

  def answer
    authorize @feedback_request, :answer?
    
    @questions = @feedback_request.feedback_request_questions.ordered.includes(:rateable)
    
    # Load resources for optional ratings (for questions without rateable)
    @assignments = company.assignments.ordered
    @abilities = company.abilities.order(:name)
    @aspirations = company.aspirations.ordered
  end

  def submit_answers
    authorize @feedback_request, :answer?
    
    answers = params[:answers] || {}
    privacy_level = params[:privacy_level] || 'observed_and_managers'
    
    result = FeedbackRequests::AnswerService.call(
      feedback_request: @feedback_request,
      answers: answers,
      responder_teammate: current_company_teammate,
      privacy_level: privacy_level
    )
    
    if result.ok?
      redirect_to organization_feedback_request_path(organization, @feedback_request),
                  notice: 'Your feedback has been submitted successfully.'
    else
      @questions = @feedback_request.feedback_request_questions.ordered.includes(:rateable)
      @assignments = company.assignments.ordered
      @abilities = company.abilities.order(:name)
      @aspirations = company.aspirations.ordered
      
      flash[:alert] = result.error
      render :answer, status: :unprocessable_entity
    end
  end

  private

  def calculate_spotlight_stats
    all_requests = FeedbackRequestsQuery.new(organization, params.except(:sort), current_person: current_person).call
    
    case @current_spotlight
    when 'open_requests'
      open_requests = all_requests.not_deleted
      {
        open_requests: open_requests.count,
        total_requests: all_requests.count,
        with_responses: open_requests.select { |r| r.has_responses? }.count,
        without_responses: open_requests.select { |r| !r.has_responses? }.count
      }
    when 'open_responders'
      open_requests = all_requests.not_deleted
      total_responders = open_requests.sum { |r| r.responders.count }
      responded_count = open_requests.sum { |r| r.responder_response_count }
      unanswered_count = total_responders - responded_count
      
      {
        total_responders: total_responders,
        responded_count: responded_count,
        unanswered_count: unanswered_count,
        open_requests: open_requests.count
      }
    when 'responder_count'
      open_requests = all_requests.not_deleted
      {
        total_responders: open_requests.sum { |r| r.responders.count },
        responded_count: open_requests.sum { |r| r.responder_response_count },
        open_requests: open_requests.count
      }
    else # 'overview'
      open_requests = all_requests.not_deleted
      {
        open_requests: open_requests.count,
        total_requests: all_requests.count,
        with_responses: open_requests.select { |r| r.has_responses? }.count,
        total_responders: open_requests.sum { |r| r.responders.count },
        responded_count: open_requests.sum { |r| r.responder_response_count }
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
end
