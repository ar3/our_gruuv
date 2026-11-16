# frozen_string_literal: true

class Organizations::Titles::MaapProposalsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_title
  before_action :set_proposal, only: %i[show edit update destroy submit apply reject]
  before_action :set_form_options, only: %i[edit update]
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
      .for_proposable(@title)
      .with_statuses(@selected_statuses)
      .created_first
      .includes(proposer: :person)
  end

  def show
    authorize @proposal
    @payload = MaapProposals::TitlePayload.from_hash(@proposal.proposed_payload)
    @diff_baseline = if @proposal.baseline_payload.present?
      MaapProposals::TitlePayload.from_hash(@proposal.baseline_payload)
    else
      MaapProposals::TitlePayload.from_title(@title)
    end
    @field_diffs = MaapProposals::TitleDiffBuilder.call(before: @diff_baseline, after: @payload)
  end

  def new
    authorize MaapProposal
    result = MaapProposals::CreateTitleEditDraft.call(
      title: @title,
      proposer: current_company_teammate
    )
    if result.ok?
      redirect_to edit_organization_title_maap_proposal_path(@organization, @title, result.value),
                  notice: "Draft proposal created. Edit and submit when ready."
    else
      redirect_to organization_title_path(@organization, @title),
                  alert: Array(result.error).join(", ")
    end
  end

  def edit
    authorize @proposal
    @payload = MaapProposals::TitlePayload.from_hash(@proposal.proposed_payload)
  end

  def update
    authorize @proposal
    result = MaapProposals::UpdateTitleEditDraft.call(
      proposal: @proposal,
      attributes: proposal_attributes
    )

    if result.ok?
      redirect_to organization_title_maap_proposal_path(@organization, @title, @proposal),
                  notice: "Draft proposal updated."
    else
      @payload = MaapProposals::TitlePayload.from_hash(
        @proposal.proposed_payload.merge(proposal_attributes.stringify_keys)
      )
      flash.now[:alert] = Array(result.error).join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @proposal
    @proposal.destroy!
    redirect_to organization_title_maap_proposals_path(@organization, @title),
                notice: "Proposal deleted."
  end

  def submit
    authorize @proposal
    result = MaapProposals::SubmitTitleEdit.call(proposal: @proposal)
    if result.ok?
      redirect_to organization_title_maap_proposal_path(@organization, @title, @proposal),
                  notice: "Proposal submitted for review."
    else
      redirect_to organization_title_maap_proposal_path(@organization, @title, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def apply
    authorize @proposal
    result = MaapProposals::ApplyTitleEdit.call(
      proposal: @proposal,
      decided_by: current_company_teammate,
      decision_note: params[:decision_note]
    )
    if result.ok?
      redirect_to organization_title_path(@organization, @title),
                  notice: "Proposal applied to the title."
    else
      redirect_to organization_title_maap_proposal_path(@organization, @title, @proposal),
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
      redirect_to organization_title_maap_proposals_path(@organization, @title),
                  notice: "Proposal rejected."
    else
      redirect_to organization_title_maap_proposal_path(@organization, @title, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  private

  def set_title
    @title = Title.for_company(@organization).find(params[:title_id])
  end

  def set_proposal
    @proposal = MaapProposal.for_organization(@organization).for_proposable(@title).find(params[:id])
  end

  def set_form_options
    @position_major_levels = PositionMajorLevel.order(:id)
    @departments = Department.where(company: @organization).order(:name)
  end

  def proposal_attributes
    params.require(:maap_proposal).permit(
      :external_title,
      :position_major_level_id,
      :department_id,
      :position_summary,
      :alternative_titles
    ).to_h
  end
end
