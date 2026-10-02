# frozen_string_literal: true

class Organizations::MaapAssignmentCreatesController < Organizations::OrganizationNamespaceBaseController
  before_action :set_proposal, only: %i[show edit update destroy submit apply reject markdown]
  after_action :verify_authorized

  def index
    authorize MaapProposal
    @filterable_statuses = %w[draft submitted applied rejected]
    @selected_statuses = if params.key?(:statuses)
      Array(params[:statuses]).map(&:to_s) & @filterable_statuses
    else
      @filterable_statuses.dup
    end
    @proposals = policy_scope(MaapProposal)
      .assignment_creates
      .for_organization(@organization)
      .with_statuses(@selected_statuses)
      .created_first
      .includes(proposer: :person, proposable: [])
  end

  def markdown_template
    authorize MaapProposal, :markdown_template?
    create_key = SecureRandom.uuid
    payload = MaapProposals::AssignmentPayload.blank_for_create
    body = MaapProposals::AssignmentMarkdownSerializer.call(
      payload: payload,
      kind: "create",
      create_key: create_key
    )
    send_data body,
              filename: "assignment-create-proposal-template.md",
              type: "text/markdown; charset=utf-8",
              disposition: "attachment"
  end

  def new
    authorize MaapProposal
    result = MaapProposals::CreateAssignmentCreateDraft.call(
      organization: @organization,
      proposer: current_company_teammate
    )
    if result.ok?
      redirect_to edit_organization_maap_assignment_create_path(@organization, result.value),
                  notice: "Draft create proposal started. Edit and submit when ready."
    else
      redirect_to organization_maap_assignment_creates_path(@organization),
                  alert: Array(result.error).join(", ")
    end
  end

  def show
    authorize @proposal
    @payload = MaapProposals::AssignmentPayload.from_hash(@proposal.proposed_payload)
    @diff_baseline = if @proposal.baseline_payload.present?
      MaapProposals::AssignmentPayload.from_hash(@proposal.baseline_payload)
    else
      MaapProposals::AssignmentPayload.empty
    end
    @field_diffs = MaapProposals::AssignmentDiffBuilder.call(
      before: @diff_baseline,
      after: @payload
    )
    @title_uniqueness = title_uniqueness_for(@proposal, @payload) if @proposal.submitted?
  end

  def edit
    authorize @proposal
    @payload = MaapProposals::AssignmentPayload.from_hash(@proposal.proposed_payload)
    load_edit_collections
  end

  def update
    authorize @proposal
    result = MaapProposals::UpdateAssignmentEditDraft.call(
      proposal: @proposal,
      attributes: proposal_attributes,
      outcomes: outcomes_from_params,
      ability_milestones: ability_milestones_from_params,
      consumer_assignment_ids: id_list_from_params(:consumer_assignment_ids),
      supplier_assignment_ids: id_list_from_params(:supplier_assignment_ids)
    )

    if result.ok?
      redirect_to organization_maap_assignment_create_path(@organization, @proposal),
                  notice: "Draft create proposal updated."
    else
      @payload = MaapProposals::AssignmentPayload.from_hash(
        @proposal.proposed_payload.merge(proposal_attributes.stringify_keys)
      )
      load_edit_collections
      flash.now[:alert] = Array(result.error).join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @proposal
    @proposal.destroy!
    redirect_to organization_maap_assignment_creates_path(@organization),
                notice: "Create proposal deleted."
  end

  def submit
    authorize @proposal
    result = MaapProposals::SubmitAssignmentEdit.call(proposal: @proposal)
    if result.ok?
      redirect_to organization_maap_assignment_create_path(@organization, @proposal),
                  notice: "Create proposal submitted for review."
    else
      redirect_to organization_maap_assignment_create_path(@organization, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def apply
    authorize @proposal
    result = MaapProposals::ApplyAssignmentCreate.call(
      proposal: @proposal,
      decided_by: current_company_teammate,
      decision_note: params[:decision_note]
    )
    if result.ok?
      assignment = result.value.proposable
      redirect_to organization_assignment_path(@organization, assignment),
                  notice: "Assignment created from proposal."
    else
      redirect_to organization_maap_assignment_create_path(@organization, @proposal),
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
      redirect_to organization_maap_assignment_creates_path(@organization),
                  notice: "Create proposal rejected."
    else
      redirect_to organization_maap_assignment_create_path(@organization, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def markdown
    authorize @proposal
    payload = MaapProposals::AssignmentPayload.from_hash(@proposal.proposed_payload)
    body = MaapProposals::AssignmentMarkdownSerializer.call(
      payload: payload,
      kind: "create",
      create_key: @proposal.create_key
    )
    filename = "assignment-create-proposal-#{@proposal.id}.md"
    send_data body, filename: filename, type: "text/markdown; charset=utf-8", disposition: "attachment"
  end

  def upload_markdown
    authorize MaapProposal, :upload_markdown?
    markdown = read_uploaded_markdown
    if markdown.blank?
      redirect_to organization_maap_assignment_creates_path(@organization),
                  alert: "Upload a markdown file."
      return
    end

    result = MaapProposals::UploadAssignmentCreateMarkdown.call(
      organization: @organization,
      proposer: current_company_teammate,
      markdown: markdown
    )

    if result.ok?
      redirect_to edit_organization_maap_assignment_create_path(@organization, result.value),
                  notice: "Draft create proposal created from markdown upload."
    else
      redirect_to organization_maap_assignment_creates_path(@organization),
                  alert: Array(result.error).join(", ")
    end
  end

  private

  def set_proposal
    @proposal = policy_scope(MaapProposal)
      .assignment_creates
      .for_organization(@organization)
      .includes(decided_by: :person, proposable: [])
      .find(params[:id])
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
    raw = params.dig(:maap_proposal, :outcomes)
    return [] if raw.blank?

    Array(raw).map do |row|
      row.permit(:id, :description, :outcome_type).to_h
    end
  end

  def ability_milestones_from_params
    raw = params.dig(:maap_proposal, :ability_milestones)
    return [] if raw.blank?

    Array(raw).map do |row|
      row.permit(:ability_id, :milestone_level).to_h
    end
  end

  def id_list_from_params(key)
    raw = params.dig(:maap_proposal, key)
    return [] if raw.blank?

    Array(raw).reject(&:blank?)
  end

  def load_edit_collections
    @abilities = Ability.for_company(@organization).includes(:department).order(:name)
    @assignments_for_reliance = Assignment.where(company: @organization)
                                          .includes(:department)
                                          .order(:title)
  end

  def read_uploaded_markdown
    file = params[:markdown_file]
    return params[:markdown_body].to_s if file.blank?

    file.read.to_s
  end

  def title_uniqueness_for(proposal, payload)
    MaapProposals::TitleUniqueness.call(
      organization: proposal.organization,
      proposed_title: payload.title,
      mode: :create
    )
  end
end
