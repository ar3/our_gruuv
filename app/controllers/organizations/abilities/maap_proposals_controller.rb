# frozen_string_literal: true

class Organizations::Abilities::MaapProposalsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_ability
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
      .for_proposable(@ability)
      .with_statuses(@selected_statuses)
      .created_first
      .includes(proposer: :person)
  end

  def markdown_template
    authorize MaapProposal, :markdown_template?
    payload = MaapProposals::AbilityPayload.from_ability(@ability)
    body = MaapProposals::AbilityMarkdownSerializer.call(
      ability: @ability,
      payload: payload,
      based_on_semantic_version: @ability.semantic_version
    )
    filename = "ability-#{@ability.id}-proposal-template.md"
    send_data body, filename: filename, type: "text/markdown; charset=utf-8", disposition: "attachment"
  end

  def show
    authorize @proposal
    @payload = MaapProposals::AbilityPayload.from_hash(@proposal.proposed_payload)
    @diff_baseline = if @proposal.baseline_payload.present?
      MaapProposals::AbilityPayload.from_hash(@proposal.baseline_payload)
    else
      MaapProposals::AbilityPayload.from_ability(@ability)
    end
    @field_diffs = MaapProposals::AbilityDiffBuilder.call(
      before: @diff_baseline,
      after: @payload
    )
    if @proposal.submitted?
      @name_uniqueness = MaapProposals::AbilityNameUniqueness.call(
        organization: @organization,
        proposed_name: @payload.name,
        excluding_ability: @ability
      )
    end
  end

  def new
    authorize MaapProposal
    result = MaapProposals::CreateAbilityEditDraft.call(
      ability: @ability,
      proposer: current_company_teammate
    )
    if result.ok?
      redirect_to edit_organization_ability_maap_proposal_path(@organization, @ability, result.value),
                  notice: "Draft proposal created. Edit and submit when ready."
    else
      redirect_to organization_ability_path(@organization, @ability),
                  alert: Array(result.error).join(", ")
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
      redirect_to organization_ability_maap_proposal_path(@organization, @ability, @proposal),
                  notice: "Draft proposal updated."
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
    redirect_to organization_ability_maap_proposals_path(@organization, @ability),
                notice: "Proposal deleted."
  end

  def submit
    authorize @proposal
    result = MaapProposals::SubmitAbilityEdit.call(proposal: @proposal)
    if result.ok?
      redirect_to organization_ability_maap_proposal_path(@organization, @ability, @proposal),
                  notice: "Proposal submitted for review."
    else
      redirect_to organization_ability_maap_proposal_path(@organization, @ability, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def apply
    authorize @proposal
    result = MaapProposals::ApplyAbilityEdit.call(
      proposal: @proposal,
      decided_by: current_company_teammate,
      version_type: params[:version_type],
      decision_note: params[:decision_note]
    )
    if result.ok?
      redirect_to organization_ability_path(@organization, @ability),
                  notice: "Proposal applied to the ability."
    else
      redirect_to organization_ability_maap_proposal_path(@organization, @ability, @proposal),
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
      redirect_to organization_ability_maap_proposals_path(@organization, @ability),
                  notice: "Proposal rejected."
    else
      redirect_to organization_ability_maap_proposal_path(@organization, @ability, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def markdown
    authorize @proposal
    payload = MaapProposals::AbilityPayload.from_hash(@proposal.proposed_payload)
    body = MaapProposals::AbilityMarkdownSerializer.call(
      ability: @ability,
      payload: payload,
      based_on_semantic_version: @proposal.based_on_semantic_version
    )
    filename = "ability-#{@ability.id}-proposal-#{@proposal.id}.md"
    send_data body, filename: filename, type: "text/markdown; charset=utf-8", disposition: "attachment"
  end

  def upload_markdown
    authorize MaapProposal, :upload_markdown?
    markdown = read_uploaded_markdown
    if markdown.blank?
      redirect_to organization_ability_maap_proposals_path(@organization, @ability),
                  alert: "Upload a markdown file."
      return
    end

    result = MaapProposals::UploadAbilityMarkdown.call(
      ability: @ability,
      proposer: current_company_teammate,
      markdown: markdown
    )

    if result.ok?
      redirect_to edit_organization_ability_maap_proposal_path(@organization, @ability, result.value),
                  notice: "Draft created from markdown upload."
    else
      redirect_to organization_ability_maap_proposals_path(@organization, @ability),
                  alert: Array(result.error).join(", ")
    end
  end

  private

  def set_ability
    @ability = Ability.where(company: @organization).find_by_param(params[:ability_id])
  end

  def set_proposal
    @proposal = MaapProposal.for_proposable(@ability).includes(decided_by: :person).find(params[:id])
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
