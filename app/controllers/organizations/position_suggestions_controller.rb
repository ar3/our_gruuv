# frozen_string_literal: true

class Organizations::PositionSuggestionsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_suggestion, only: [
    :show, :join, :update_participation, :close, :create_comment, :upsert_milestone, :upsert_assignment_draft
  ]
  after_action :verify_authorized

  def index
    authorize PositionSuggestion
    load_list_shared_state
    partition_open_rounds
    partition_start_positions
  end

  def closed
    authorize PositionSuggestion, :closed?
    load_list_shared_state
    partition_closed_rounds
  end

  def show
    authorize @suggestion

    ensure_joined_if_open!
    load_show_context
  end

  def create
    position = Position.for_company(company).unarchived.find(params[:position_id])
    authorize PositionSuggestion.new(organization: organization, position: position), :create?

    result = PositionSuggestions::FindOrOpenService.call(
      position: position,
      organization: organization,
      opened_by: current_company_teammate
    )

    if result.ok?
      redirect_to organization_position_suggestion_path(organization, result.value),
                  notice: "Opened suggestion round for #{position.display_name}."
    else
      redirect_to organization_position_suggestions_path(organization),
                  alert: Array(result.error).join(", ")
    end
  end

  def join
    authorize @suggestion, :join?

    result = PositionSuggestions::JoinService.call(
      suggestion: @suggestion,
      company_teammate: current_company_teammate
    )

    if result.ok?
      redirect_to organization_position_suggestion_path(organization, @suggestion),
                  notice: "You joined this suggestion round."
    else
      redirect_to organization_position_suggestion_path(organization, @suggestion),
                  alert: Array(result.error).join(", ")
    end
  end

  def update_participation
    authorize @suggestion, :update?

    participant = @suggestion.participant_for(current_company_teammate)
    unless participant
      redirect_to organization_position_suggestion_path(organization, @suggestion),
                  alert: "Join this round before updating your status." and return
    end

    case params[:participation_status]
    when "done_contributing"
      unless @suggestion.has_made_suggestions_for?(current_company_teammate)
        redirect_to organization_position_suggestion_path(organization, @suggestion),
                    alert: "Make at least one suggestion before marking this round done." and return
      end
      participant.mark_done_contributing!
      notice = "Marked as done making suggestions for this round."
    when "active"
      participant.mark_active!
      notice = "You are making suggestions again."
    when "withdrawn"
      if @suggestion.has_made_suggestions_for?(current_company_teammate)
        redirect_to organization_position_suggestion_path(organization, @suggestion),
                    alert: "You already made suggestions in this round; mark done instead of withdrawing." and return
      end
      participant.withdraw!
      notice = "You withdrew from this suggestion round."
    else
      redirect_to organization_position_suggestion_path(organization, @suggestion),
                  alert: "Unknown participation status." and return
    end

    redirect_to organization_position_suggestions_path(organization), notice: notice
  end

  def close
    authorize @suggestion, :close?

    begin
      @suggestion.complete!(closed_by: current_company_teammate)
      redirect_to organization_position_suggestions_path(organization),
                  notice: "Suggestion round completed."
    rescue ArgumentError => e
      redirect_to organization_position_suggestion_path(organization, @suggestion),
                  alert: e.message
    end
  end

  def create_comment
    authorize @suggestion, :create_comment?

    ensure_joined_if_open!
    commentable = find_suggestion_commentable!
    comment = Comment.new(body: params.require(:comment).permit(:body)[:body])

    result = Comments::CreateService.call(
      comment: comment,
      commentable: commentable,
      organization: organization,
      creator: current_person,
      position_suggestion: @suggestion
    )

    if result.ok?
      redirect_to organization_position_suggestion_path(organization, @suggestion, anchor: comment_anchor(commentable)),
                  notice: "Comment added."
    else
      redirect_to organization_position_suggestion_path(organization, @suggestion),
                  alert: Array(result.error).join(", ")
    end
  end

  def upsert_milestone
    authorize @suggestion, :update_milestone?

    milestoneable = find_milestoneable!
    result = PositionSuggestions::UpsertMilestoneService.call(
      suggestion: @suggestion,
      milestoneable: milestoneable,
      suggested_milestone_level: params.require(:suggested_milestone_level),
      modified_by: current_company_teammate
    )

    if result.ok?
      anchor =
        if milestoneable.respond_to?(:assignment_id)
          "assignment-#{milestoneable.assignment_id}"
        else
          "position-comments"
        end
      redirect_to organization_position_suggestion_path(organization, @suggestion, anchor: anchor),
                  notice: "Suggested milestone saved (not applied to MAAP yet)."
    else
      redirect_to organization_position_suggestion_path(organization, @suggestion),
                  alert: Array(result.error).join(", ")
    end
  end

  def upsert_assignment_draft
    authorize @suggestion, :update_assignment_draft?

    assignment = find_source_assignment!
    attrs = params.require(:assignment_draft).permit(
      :title, :tagline, :required_activities, :handbook, :outcomes_text
    )
    outcomes = outcomes_from_params(attrs[:outcomes_text], assignment)

    result = PositionSuggestions::UpsertAssignmentDraftService.call(
      suggestion: @suggestion,
      source_assignment: assignment,
      attributes: attrs.slice(:title, :tagline, :required_activities, :handbook),
      outcomes: outcomes,
      modified_by: current_company_teammate
    )

    if result.ok?
      redirect_to organization_position_suggestion_path(
                    organization,
                    @suggestion,
                    anchor: "assignment-#{assignment.id}-fields"
                  ),
                  notice: "Assignment field suggestions saved (not applied to MAAP yet)."
    else
      redirect_to organization_position_suggestion_path(organization, @suggestion, anchor: "assignment-#{assignment.id}-fields"),
                  alert: Array(result.error).join(", ")
    end
  end

  private

  def set_suggestion
    @suggestion = PositionSuggestion.for_organization(organization).find(params[:id])
  end

  def ensure_joined_if_open!
    return unless @suggestion.open?
    return if @suggestion.participant_for(current_company_teammate)

    PositionSuggestions::JoinService.call(
      suggestion: @suggestion,
      company_teammate: current_company_teammate
    )
  end

  def load_show_context
    @position = @suggestion.position
    @participant = @suggestion.participant_for(current_company_teammate)
    @position_assignments = @position.position_assignments
      .includes(assignment: [:assignment_outcomes, { assignment_abilities: :ability }])
      .sort_by { |pa| [pa.assignment_type == "required" ? 0 : 1, pa.assignment.title.to_s.downcase] }
    @milestones_by_key = @suggestion.milestones.includes(:last_modified_by, :milestoneable).index_by do |m|
      [m.milestoneable_type, m.milestoneable_id]
    end
    @assignment_drafts_by_assignment_id = @suggestion.assignment_drafts
      .includes(:outcomes, :last_modified_by)
      .index_by(&:source_assignment_id)
    @position_comments = @suggestion.comments
      .for_commentable(@position)
      .root_comments
      .ordered
      .includes(:creator)
    @assignment_comments = @suggestion.comments
      .where(commentable_type: "Assignment", commentable_id: @position_assignments.map(&:assignment_id))
      .root_comments
      .ordered
      .includes(:creator)
      .group_by(&:commentable_id)
    @can_manage_maap = current_company_teammate.can_manage_maap?
    @return_to = organization_position_suggestion_path(organization, @suggestion)
    @viewer_has_made_suggestions = @suggestion.has_made_suggestions_for?(current_company_teammate)
    summary = PositionSuggestions::RoundSummaryBuilder.call(suggestion: @suggestion)
    @round_timeline = summary[:timeline]
    @process_rows = summary[:process_rows]
    @viewer_casual_name = current_person.casual_name
  end

  def find_suggestion_commentable!
    type = params.require(:commentable_type)
    id = params.require(:commentable_id)

    case type
    when "Position"
      raise ActiveRecord::RecordNotFound unless id.to_i == @suggestion.position_id

      @suggestion.position
    when "Assignment"
      assignment = Assignment.find(id)
      unless @suggestion.position.assignments.exists?(id: assignment.id)
        raise ActiveRecord::RecordNotFound, "Assignment not on this position"
      end

      assignment
    else
      raise ActiveRecord::RecordNotFound, "Unsupported commentable"
    end
  end

  def find_source_assignment!
    assignment = Assignment.find(params.require(:source_assignment_id))
    unless @suggestion.position.assignments.exists?(id: assignment.id)
      raise ActiveRecord::RecordNotFound, "Assignment not on this position"
    end

    assignment
  end

  # One outcome description per line. Prefer draft outcome types by line index when re-saving;
  # otherwise keep live types by index, defaulting to quantitative.
  def outcomes_from_params(outcomes_text, assignment)
    lines = outcomes_text.to_s.lines.map(&:strip).reject(&:blank?)
    draft = @suggestion.assignment_drafts.find_by(source_assignment: assignment)
    baseline = draft&.outcomes&.order(:position, :id)&.to_a
    baseline ||= assignment.assignment_outcomes.ordered.to_a

    lines.each_with_index.map do |description, index|
      existing = baseline[index]
      {
        description: description,
        outcome_type: existing&.outcome_type.presence || "quantitative",
        progress_report_url: existing&.try(:progress_report_url),
        management_relationship_filter: existing&.try(:management_relationship_filter),
        team_relationship_filter: existing&.try(:team_relationship_filter),
        consumer_assignment_filter: existing&.try(:consumer_assignment_filter)
      }
    end
  end

  def find_milestoneable!
    type = params.require(:milestoneable_type)
    id = params.require(:milestoneable_id)

    case type
    when "AssignmentAbility"
      aa = AssignmentAbility.find(id)
      unless @suggestion.position.assignments.exists?(id: aa.assignment_id)
        raise ActiveRecord::RecordNotFound, "Assignment ability not on this position"
      end

      aa
    when "PositionAbility"
      pa = PositionAbility.find(id)
      raise ActiveRecord::RecordNotFound unless pa.position_id == @suggestion.position_id

      pa
    else
      raise ActiveRecord::RecordNotFound, "Unsupported milestoneable"
    end
  end

  def comment_anchor(commentable)
    if commentable.is_a?(Position)
      "position-comments"
    else
      "assignment-#{commentable.id}"
    end
  end

  def interested_position_ids
    relevant_position_ids.to_a
  end

  def load_list_shared_state
    @positions = Position.for_company(company).unarchived.includes(:position_level, title: :department).to_a
    @open_suggestions = PositionSuggestion
      .for_organization(organization)
      .open_sessions
      .includes(:participants, position: [:position_level, { title: :department }])
      .to_a
    @closed_suggestions = PositionSuggestion
      .for_organization(organization)
      .completed_sessions
      .includes(:participants, position: [:position_level, { title: :department }])
      .to_a
    @my_participations = PositionSuggestionParticipant
      .joins(:position_suggestion)
      .where(company_teammate: current_company_teammate)
      .where(position_suggestions: { organization_id: organization.id })
      .includes(position_suggestion: { position: [:position_level, { title: :department }] })
      .to_a
    @participation_by_suggestion_id = @my_participations.index_by(&:position_suggestion_id)
    load_relevant_scope!
    @relevant_position_ids = @relevant_position_ids_memo
    @relevant_department_labels = @relevant_department_labels_memo
    @closed_rounds_count = @closed_suggestions.size
  end

  def partition_open_rounds
    active_ids = Set.new
    @actively_suggesting = sort_suggestions(
      @my_participations.select(&:active?).filter_map do |participation|
        suggestion = participation.position_suggestion
        next unless suggestion.open?

        active_ids << suggestion.id
        suggestion
      end
    )

    remaining = @open_suggestions.reject { |s| active_ids.include?(s.id) }
    relevant, others = remaining.partition { |s| relevant_position?(s.position) }
    @relevant_open_rounds = sort_suggestions(relevant)
    @other_open_rounds = sort_suggestions(others)
  end

  def partition_start_positions
    open_position_ids = @open_suggestions.map(&:position_id).to_set
    available = @positions.reject { |position| open_position_ids.include?(position.id) }
    relevant, others = available.partition { |position| relevant_position?(position) }
    @relevant_start_positions = sort_positions(relevant)
    @other_start_positions = sort_positions(others)
  end

  def partition_closed_rounds
    # Withdrawal is treated like never participating.
    my_closed = @my_participations
      .reject(&:withdrawn?)
      .map(&:position_suggestion)
      .select(&:completed?)
      .uniq
    my_closed_ids = my_closed.map(&:id).to_set

    not_mine = @closed_suggestions.reject { |s| my_closed_ids.include?(s.id) }
    relevant, others = not_mine.partition { |s| relevant_position?(s.position) }

    @closed_i_joined = sort_suggestions(my_closed)
    @closed_relevant = sort_suggestions(relevant)
    @closed_other = sort_suggestions(others)
  end

  # Departments of titles for: self + direct reports (active employment).
  # Relevant positions = every unarchived position in those departments
  # (or company-wide when any source title is company-wide).
  def load_relevant_scope!
    return if defined?(@relevant_position_ids_memo)

    teammate_ids = [current_company_teammate.id]
    teammate_ids.concat(
      EmploymentTenure.active
        .where(manager_teammate_id: current_company_teammate.id, company_id: company.id)
        .pluck(:teammate_id)
    )
    teammate_ids.uniq!

    source_positions = EmploymentTenure.active
      .where(teammate_id: teammate_ids, company_id: company.id)
      .where.not(position_id: nil)
      .includes(position: { title: :department })
      .map(&:position)
      .compact

    department_ids = Set.new
    includes_company_wide = false
    source_positions.each do |position|
      dept_id = position.title&.department_id
      if dept_id.nil?
        includes_company_wide = true
      else
        department_ids << dept_id
      end
    end

    departments = Department.where(id: department_ids.to_a).to_a
    labels = departments.map(&:display_name).sort_by(&:downcase)
    labels.unshift("Company-wide") if includes_company_wide
    @relevant_department_labels_memo = labels

    ids = Set.new
    Position.for_company(company).unarchived.includes(title: :department).find_each do |position|
      dept_id = position.title&.department_id
      if dept_id.nil?
        ids << position.id if includes_company_wide
      elsif department_ids.include?(dept_id)
        ids << position.id
      end
    end

    @relevant_position_ids_memo = ids
  rescue StandardError
    @relevant_position_ids_memo = Set.new
    @relevant_department_labels_memo = []
  end

  def relevant_position_ids
    load_relevant_scope!
    @relevant_position_ids_memo
  end

  def relevant_position?(position)
    return false unless position

    relevant_position_ids.include?(position.id)
  end

  def sort_suggestions(suggestions)
    suggestions.sort_by { |suggestion| position_sort_key(suggestion.position) }
  end

  def sort_positions(positions)
    positions.sort_by { |position| position_sort_key(position) }
  end

  # Matches Positions index grouping/sort: company-wide first, department display_name,
  # title external_title, then level / full display name.
  def position_sort_key(position)
    return [2, "", "", "", ""] unless position

    title = position.title
    department = title&.department
    [
      department ? 1 : 0,
      department&.display_name.to_s.downcase,
      title&.external_title.to_s.downcase,
      position.position_level&.level.to_s,
      position.display_name.to_s.downcase
    ]
  end

  def position_department_sort_key(position)
    position_sort_key(position)
  end

  def sort_suggestions_by_department(suggestions)
    sort_suggestions(suggestions)
  end

  def sort_positions_by_department(positions)
    sort_positions(positions)
  end
end
