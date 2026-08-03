# frozen_string_literal: true

class Organizations::PositionSuggestionsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_suggestion, only: [
    :show, :join, :update_participation, :close, :create_comment, :upsert_milestone
  ]
  after_action :verify_authorized

  def index
    authorize PositionSuggestion

    @positions = Position.for_company(company).unarchived.includes(:position_level, title: :department)
    @open_suggestions = PositionSuggestion
      .for_organization(organization)
      .open_sessions
      .includes(:participants, position: [:position_level, { title: :department }])
      .recent_first
    @my_participations = PositionSuggestionParticipant
      .joins(:position_suggestion)
      .where(company_teammate: current_company_teammate)
      .where(position_suggestions: { organization_id: organization.id })
      .includes(position_suggestion: { position: [:position_level, { title: :department }] })

    @actively_reviewing = sort_suggestions_by_department(
      @my_participations.select(&:active?).map(&:position_suggestion)
    )
    @done_contributing = @my_participations.select(&:done_contributing?).map(&:position_suggestion)
    actively_reviewing_ids = @actively_reviewing.map(&:id)
    @other_open_suggestions = sort_suggestions_by_department(
      @open_suggestions.reject { |suggestion| actively_reviewing_ids.include?(suggestion.id) }
    )

    occupied_position_ids = @open_suggestions.map(&:position_id).to_set
    available_positions = @positions.reject { |position| occupied_position_ids.include?(position.id) }
    available_positions = sort_positions_by_department(available_positions)

    @interested_position_ids = interested_position_ids
    @interested_start_positions = available_positions.select { |p| @interested_position_ids.include?(p.id) }
    @other_start_positions = available_positions.reject { |p| @interested_position_ids.include?(p.id) }
    @completed_suggestions = sort_suggestions_by_department(
      @my_participations.select { |p| p.position_suggestion.completed? }.map(&:position_suggestion).uniq
    )
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
                  notice: "Opened suggestion session for #{position.display_name}."
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
                  notice: "You joined this suggestion session."
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
                  alert: "Join this session before updating your status." and return
    end

    case params[:participation_status]
    when "done_contributing"
      participant.mark_done_contributing!
      notice = "Marked as done contributing. Your queue is clear for this position."
    when "active"
      participant.mark_active!
      notice = "You are actively reviewing again."
    when "withdrawn"
      participant.withdraw!
      notice = "You withdrew from this suggestion session."
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
                  notice: "Suggestion session completed."
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
    ids = Set.new

    tenure_position_ids = EmploymentTenure.active
      .where(teammate_id: current_company_teammate.id)
      .where.not(position_id: nil)
      .pluck(:position_id)
    ids.merge(tenure_position_ids)

    if current_company_teammate.has_direct_reports?
      report_person_ids = EmployeeHierarchyQuery
        .new(person: current_person, organization: organization)
        .call
        .map { |info| info[:person_id] }
        .compact
      report_teammate_ids = CompanyTeammate.where(organization: organization, person_id: report_person_ids).pluck(:id)
      ids.merge(
        EmploymentTenure.active.where(teammate_id: report_teammate_ids).where.not(position_id: nil).pluck(:position_id)
      )
    end

    ids.to_a
  rescue StandardError
    []
  end

  def sort_suggestions_by_department(suggestions)
    suggestions.sort_by do |suggestion|
      position_department_sort_key(suggestion.position)
    end
  end

  def sort_positions_by_department(positions)
    positions.sort_by { |position| position_department_sort_key(position) }
  end

  def position_department_sort_key(position)
    department_name = position.title&.department&.name.to_s.downcase
    [
      department_name.present? ? 0 : 1,
      department_name,
      position.display_name.to_s.downcase
    ]
  end
end
