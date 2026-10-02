# frozen_string_literal: true

class Organizations::MaapAbilityCreatesController < Organizations::OrganizationNamespaceBaseController
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
      .ability_creates
      .for_organization(@organization)
      .with_statuses(@selected_statuses)
      .created_first
      .includes(proposer: :person, proposable: [])
  end

  def markdown_template
    authorize MaapProposal, :markdown_template?
    create_key = SecureRandom.uuid
    payload = MaapProposals::AbilityPayload.blank_for_create
    body = MaapProposals::AbilityMarkdownSerializer.call(
      payload: payload,
      kind: "create",
      create_key: create_key
    )
    send_data body,
              filename: "ability-create-proposal-template.md",
              type: "text/markdown; charset=utf-8",
              disposition: "attachment"
  end

  def new
    authorize MaapProposal
    result = MaapProposals::CreateAbilityCreateDraft.call(
      organization: @organization,
      proposer: current_company_teammate
    )
    if result.ok?
      redirect_to edit_organization_maap_ability_create_path(@organization, result.value),
                  notice: "Draft Ability create proposal started. Edit and submit when ready."
    else
      redirect_to organization_maap_ability_creates_path(@organization),
                  alert: Array(result.error).join(", ")
    end
  end

  def show
    authorize @proposal
    @payload = MaapProposals::AbilityPayload.from_hash(@proposal.proposed_payload)
    @diff_baseline = if @proposal.baseline_payload.present?
      MaapProposals::AbilityPayload.from_hash(@proposal.baseline_payload)
    else
      MaapProposals::AbilityPayload.empty
    end
    @field_diffs = MaapProposals::AbilityDiffBuilder.call(
      before: @diff_baseline,
      after: @payload
    )
    if @proposal.submitted?
      @name_uniqueness = MaapProposals::AbilityNameUniqueness.call(
        organization: @organization,
        proposed_name: @payload.name,
        mode: :create
      )
    end
  end

  def edit
    authorize @proposal
    @payload = MaapProposals::AbilityPayload.from_hash(@proposal.proposed_payload)
  end

  def update
    authorize @proposal
    result = MaapProposals::UpdateAbilityEditDraft.call(
      proposal: @proposal,
      attributes: proposal_attributes
    )

    if result.ok?
      redirect_to organization_maap_ability_create_path(@organization, @proposal),
                  notice: "Draft Ability create proposal updated."
    else
      @payload = MaapProposals::AbilityPayload.from_hash(
        @proposal.proposed_payload.merge(proposal_attributes.stringify_keys)
      )
      flash.now[:alert] = Array(result.error).join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @proposal
    @proposal.destroy!
    redirect_to organization_maap_ability_creates_path(@organization),
                notice: "Ability create proposal deleted."
  end

  def submit
    authorize @proposal
    result = MaapProposals::SubmitAbilityEdit.call(proposal: @proposal)
    if result.ok?
      redirect_to organization_maap_ability_create_path(@organization, @proposal),
                  notice: "Ability create proposal submitted for review."
    else
      redirect_to organization_maap_ability_create_path(@organization, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def apply
    authorize @proposal
    result = MaapProposals::ApplyAbilityCreate.call(
      proposal: @proposal,
      decided_by: current_company_teammate,
      decision_note: params[:decision_note]
    )
    if result.ok?
      ability = result.value.proposable
      redirect_to organization_ability_path(@organization, ability),
                  notice: "Ability created from proposal."
    else
      redirect_to organization_maap_ability_create_path(@organization, @proposal),
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
      redirect_to organization_maap_ability_creates_path(@organization),
                  notice: "Ability create proposal rejected."
    else
      redirect_to organization_maap_ability_create_path(@organization, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def markdown
    authorize @proposal
    payload = MaapProposals::AbilityPayload.from_hash(@proposal.proposed_payload)
    body = MaapProposals::AbilityMarkdownSerializer.call(
      payload: payload,
      kind: "create",
      create_key: @proposal.create_key
    )
    filename = "ability-create-proposal-#{@proposal.id}.md"
    send_data body, filename: filename, type: "text/markdown; charset=utf-8", disposition: "attachment"
  end

  def upload_markdown
    authorize MaapProposal, :upload_markdown?
    markdown = read_uploaded_markdown
    if markdown.blank?
      redirect_to organization_maap_ability_creates_path(@organization),
                  alert: "Upload a markdown file."
      return
    end

    result = MaapProposals::UploadAbilityCreateMarkdown.call(
      organization: @organization,
      proposer: current_company_teammate,
      markdown: markdown
    )

    if result.ok?
      redirect_to edit_organization_maap_ability_create_path(@organization, result.value),
                  notice: "Draft Ability create proposal created from markdown upload."
    else
      redirect_to organization_maap_ability_creates_path(@organization),
                  alert: Array(result.error).join(", ")
    end
  end

  private

  def set_proposal
    @proposal = policy_scope(MaapProposal)
      .ability_creates
      .for_organization(@organization)
      .includes(decided_by: :person, proposable: [])
      .find(params[:id])
  end

  def proposal_attributes
    params.require(:maap_proposal).permit(
      :name,
      :description,
      :department_id,
      :milestone_1_description,
      :milestone_2_description,
      :milestone_3_description,
      :milestone_4_description,
      :milestone_5_description
    ).to_h
  end

  def read_uploaded_markdown
    file = params[:markdown_file]
    return params[:markdown_body].to_s if file.blank?

    file.read.to_s
  end
end
