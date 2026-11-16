# frozen_string_literal: true

class Organizations::Positions::MaapProposalsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_position
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
      .for_proposable(@position)
      .with_statuses(@selected_statuses)
      .created_first
      .includes(proposer: :person)
  end

  def show
    authorize @proposal
    @payload = MaapProposals::PositionPayload.from_hash(@proposal.proposed_payload)
    @diff_baseline = if @proposal.baseline_payload.present?
      MaapProposals::PositionPayload.from_hash(@proposal.baseline_payload)
    else
      MaapProposals::PositionPayload.from_position(@position)
    end
    @field_diffs = MaapProposals::PositionDiffBuilder.call(before: @diff_baseline, after: @payload)
  end

  def new
    authorize MaapProposal
    result = MaapProposals::CreatePositionEditDraft.call(
      position: @position,
      proposer: current_company_teammate
    )
    if result.ok?
      redirect_to edit_organization_position_maap_proposal_path(@organization, @position, result.value),
                  notice: "Draft proposal created. Edit and submit when ready."
    else
      redirect_to organization_position_path(@organization, @position),
                  alert: Array(result.error).join(", ")
    end
  end

  def edit
    authorize @proposal
    @payload = MaapProposals::PositionPayload.from_hash(@proposal.proposed_payload)
  end

  def update
    authorize @proposal
    result = MaapProposals::UpdatePositionEditDraft.call(
      proposal: @proposal,
      attributes: proposal_attributes
    )

    if result.ok?
      redirect_to organization_position_maap_proposal_path(@organization, @position, @proposal),
                  notice: "Draft proposal updated."
    else
      @payload = MaapProposals::PositionPayload.from_hash(
        @proposal.proposed_payload.merge(
          "position_summary" => proposal_attributes["position_summary"],
          "position_level_id" => proposal_attributes["position_level_id"],
          "assignment_links" => proposal_attributes["assignment_links"]
        ).compact
      )
      flash.now[:alert] = Array(result.error).join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @proposal
    @proposal.destroy!
    redirect_to organization_position_maap_proposals_path(@organization, @position),
                notice: "Proposal deleted."
  end

  def submit
    authorize @proposal
    result = MaapProposals::SubmitPositionEdit.call(proposal: @proposal)
    if result.ok?
      redirect_to organization_position_maap_proposal_path(@organization, @position, @proposal),
                  notice: "Proposal submitted for review."
    else
      redirect_to organization_position_maap_proposal_path(@organization, @position, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def apply
    authorize @proposal
    result = MaapProposals::ApplyPositionEdit.call(
      proposal: @proposal,
      decided_by: current_company_teammate,
      decision_note: params[:decision_note]
    )
    if result.ok?
      redirect_to organization_position_path(@organization, @position),
                  notice: "Proposal applied to the position."
    else
      redirect_to organization_position_maap_proposal_path(@organization, @position, @proposal),
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
      redirect_to organization_position_maap_proposals_path(@organization, @position),
                  notice: "Proposal rejected."
    else
      redirect_to organization_position_maap_proposal_path(@organization, @position, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  private

  def set_position
    @position = Position.for_company(@organization).find(params[:position_id])
  end

  def set_proposal
    @proposal = MaapProposal.for_organization(@organization).for_proposable(@position).find(params[:id])
  end

  def set_form_options
    @position_levels = @position.title.position_major_level.position_levels.order(:level)
    @assignments = Assignment.for_company(@organization).unarchived.order(:title)
  end

  def proposal_attributes
    raw = params.require(:maap_proposal).permit(
      :position_summary,
      :position_level_id,
      assignment_links: %i[assignment_id assignment_type energy_percentage]
    ).to_h
    links = raw["assignment_links"] || raw[:assignment_links]
    raw["assignment_links"] = case links
                              when Hash then links.values
                              when Array then links
                              else []
                              end.map { |row| row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h }
    raw
  end
end
