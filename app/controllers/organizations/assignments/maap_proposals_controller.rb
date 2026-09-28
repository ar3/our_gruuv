# frozen_string_literal: true

class Organizations::Assignments::MaapProposalsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_assignment
  before_action :set_proposal, only: %i[show edit update destroy submit apply reject markdown]
  after_action :verify_authorized

  def index
    authorize MaapProposal
    @proposals = policy_scope(MaapProposal).for_proposable(@assignment).recent_first
    @assignments_by_department_for_switcher = AssignmentsByDepartmentForSwitcher.call(
      scope: policy_scope(Assignment).where(company: @organization)
    )
  end

  def markdown_template
    authorize MaapProposal, :markdown_template?
    payload = MaapProposals::AssignmentPayload.from_assignment(@assignment)
    body = MaapProposals::AssignmentMarkdownSerializer.call(
      assignment: @assignment,
      payload: payload,
      based_on_semantic_version: @assignment.semantic_version
    )
    filename = "assignment-#{@assignment.id}-proposal-template.md"
    send_data body, filename: filename, type: "text/markdown; charset=utf-8", disposition: "attachment"
  end

  def show
    authorize @proposal
    @payload = MaapProposals::AssignmentPayload.from_hash(@proposal.proposed_payload)
    @diff_baseline = if @proposal.baseline_payload.present?
      MaapProposals::AssignmentPayload.from_hash(@proposal.baseline_payload)
    else
      MaapProposals::AssignmentPayload.from_assignment(@assignment)
    end
    @field_diffs = MaapProposals::AssignmentDiffBuilder.call(
      before: @diff_baseline,
      after: @payload
    )
  end

  def new
    authorize MaapProposal
    result = MaapProposals::CreateAssignmentEditDraft.call(
      assignment: @assignment,
      proposer: current_company_teammate
    )
    if result.ok?
      redirect_to edit_organization_assignment_maap_proposal_path(@organization, @assignment, result.value),
                  notice: "Draft proposal created. Edit and submit when ready."
    else
      redirect_to organization_assignment_path(@organization, @assignment),
                  alert: Array(result.error).join(", ")
    end
  end

  def edit
    authorize @proposal
    @payload = MaapProposals::AssignmentPayload.from_hash(@proposal.proposed_payload)
  end

  def update
    authorize @proposal
    result = MaapProposals::UpdateAssignmentEditDraft.call(
      proposal: @proposal,
      attributes: proposal_attributes,
      outcomes: outcomes_from_params
    )

    if result.ok?
      redirect_to organization_assignment_maap_proposal_path(@organization, @assignment, @proposal),
                  notice: "Draft proposal updated."
    else
      @payload = MaapProposals::AssignmentPayload.from_hash(
        @proposal.proposed_payload.merge(proposal_attributes.stringify_keys)
      )
      flash.now[:alert] = Array(result.error).join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @proposal
    @proposal.destroy!
    redirect_to organization_assignment_maap_proposals_path(@organization, @assignment),
                notice: "Proposal deleted."
  end

  def submit
    authorize @proposal
    result = MaapProposals::SubmitAssignmentEdit.call(proposal: @proposal)
    if result.ok?
      redirect_to organization_assignment_maap_proposal_path(@organization, @assignment, @proposal),
                  notice: "Proposal submitted for review."
    else
      redirect_to organization_assignment_maap_proposal_path(@organization, @assignment, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def apply
    authorize @proposal
    result = MaapProposals::ApplyAssignmentEdit.call(
      proposal: @proposal,
      decided_by: current_company_teammate,
      version_type: params[:version_type],
      decision_note: params[:decision_note]
    )
    if result.ok?
      redirect_to organization_assignment_path(@organization, @assignment),
                  notice: "Proposal applied to the assignment."
    else
      redirect_to organization_assignment_maap_proposal_path(@organization, @assignment, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def reject
    authorize @proposal
    result = MaapProposals::RejectAssignmentEdit.call(
      proposal: @proposal,
      decided_by: current_company_teammate,
      decision_note: params[:decision_note]
    )
    if result.ok?
      redirect_to organization_assignment_maap_proposals_path(@organization, @assignment),
                  notice: "Proposal rejected."
    else
      redirect_to organization_assignment_maap_proposal_path(@organization, @assignment, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def markdown
    authorize @proposal
    payload = MaapProposals::AssignmentPayload.from_hash(@proposal.proposed_payload)
    body = MaapProposals::AssignmentMarkdownSerializer.call(
      assignment: @assignment,
      payload: payload,
      based_on_semantic_version: @proposal.based_on_semantic_version
    )
    filename = "assignment-#{@assignment.id}-proposal-#{@proposal.id}.md"
    send_data body, filename: filename, type: "text/markdown; charset=utf-8", disposition: "attachment"
  end

  def upload_markdown
    authorize MaapProposal, :upload_markdown?
    markdown = read_uploaded_markdown
    if markdown.blank?
      redirect_to organization_assignment_maap_proposals_path(@organization, @assignment),
                  alert: "Upload a markdown file."
      return
    end

    result = MaapProposals::UploadAssignmentMarkdown.call(
      assignment: @assignment,
      proposer: current_company_teammate,
      markdown: markdown
    )

    if result.ok?
      redirect_to edit_organization_assignment_maap_proposal_path(@organization, @assignment, result.value),
                  notice: "Draft created from markdown upload."
    else
      redirect_to organization_assignment_maap_proposals_path(@organization, @assignment),
                  alert: Array(result.error).join(", ")
    end
  end

  private

  def set_assignment
    @assignment = Assignment.where(company: @organization).find(params[:assignment_id])
  end

  def set_proposal
    @proposal = MaapProposal.for_proposable(@assignment).find(params[:id])
  end

  def proposal_attributes
    params.require(:maap_proposal).permit(
      :title,
      :tagline,
      :required_activities,
      :handbook,
      :department_id
    ).to_h
  end

  def outcomes_from_params
    # Always replace outcomes when the edit form is submitted (supports full clear).
    raw = params.dig(:maap_proposal, :outcomes)
    return [] if raw.blank?

    Array(raw).map do |row|
      row.permit(:id, :description, :outcome_type).to_h
    end
  end

  def read_uploaded_markdown
    file = params[:markdown_file]
    return params[:markdown_body].to_s if file.blank?

    file.read.to_s
  end
end
