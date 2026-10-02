# frozen_string_literal: true

class Organizations::Seats::MaapProposalsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_seat
  before_action :set_proposal, only: %i[show edit update destroy submit apply reject markdown]
  before_action :set_related_data, only: %i[edit update]
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
      .for_proposable(@seat)
      .with_statuses(@selected_statuses)
      .created_first
      .includes(proposer: :person)
  end

  def markdown_template
    authorize MaapProposal, :markdown_template?
    payload = MaapProposals::SeatPayload.from_seat(@seat)
    body = MaapProposals::SeatMarkdownSerializer.call(
      seat: @seat,
      payload: payload,
      kind: "edit"
    )
    filename = "seat-#{@seat.id}-proposal-template.md"
    send_data body, filename: filename, type: "text/markdown; charset=utf-8", disposition: "attachment"
  end

  def show
    authorize @proposal
    @payload = MaapProposals::SeatPayload.from_hash(@proposal.proposed_payload)
    @diff_baseline = if @proposal.baseline_payload.present?
      MaapProposals::SeatPayload.from_hash(@proposal.baseline_payload)
    else
      MaapProposals::SeatPayload.from_seat(@seat)
    end
    @field_diffs = MaapProposals::SeatDiffBuilder.call(
      before: @diff_baseline,
      after: @payload
    )
  end

  def new
    authorize MaapProposal
    result = MaapProposals::CreateSeatEditDraft.call(
      seat: @seat,
      proposer: current_company_teammate
    )
    if result.ok?
      redirect_to edit_organization_seat_maap_proposal_path(@organization, @seat, result.value),
                  notice: "Draft proposal created. Edit and submit when ready."
    else
      redirect_to organization_seat_path(@organization, @seat),
                  alert: Array(result.error).join(", ")
    end
  end

  def edit
    authorize @proposal
    @payload = MaapProposals::SeatPayload.from_hash(@proposal.proposed_payload)
  end

  def update
    authorize @proposal
    result = MaapProposals::UpdateSeatEditDraft.call(
      proposal: @proposal,
      attributes: proposal_attributes
    )

    if result.ok?
      redirect_to organization_seat_maap_proposal_path(@organization, @seat, @proposal),
                  notice: "Draft proposal updated."
    else
      @payload = MaapProposals::SeatPayload.from_hash(
        @proposal.proposed_payload.merge(proposal_attributes.stringify_keys)
      )
      flash.now[:alert] = Array(result.error).join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @proposal
    @proposal.destroy!
    redirect_to organization_seat_maap_proposals_path(@organization, @seat),
                notice: "Proposal deleted."
  end

  def submit
    authorize @proposal
    result = MaapProposals::SubmitSeatEdit.call(proposal: @proposal)
    if result.ok?
      redirect_to organization_seat_maap_proposal_path(@organization, @seat, @proposal),
                  notice: "Proposal submitted for review."
    else
      redirect_to organization_seat_maap_proposal_path(@organization, @seat, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def apply
    authorize @proposal
    result = MaapProposals::ApplySeatEdit.call(
      proposal: @proposal,
      decided_by: current_company_teammate,
      decision_note: params[:decision_note]
    )
    if result.ok?
      redirect_to organization_seat_path(@organization, @seat),
                  notice: "Proposal applied to the seat."
    else
      redirect_to organization_seat_maap_proposal_path(@organization, @seat, @proposal),
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
      redirect_to organization_seat_maap_proposals_path(@organization, @seat),
                  notice: "Proposal rejected."
    else
      redirect_to organization_seat_maap_proposal_path(@organization, @seat, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def markdown
    authorize @proposal
    payload = MaapProposals::SeatPayload.from_hash(@proposal.proposed_payload)
    body = MaapProposals::SeatMarkdownSerializer.call(
      seat: @seat,
      payload: payload,
      kind: "edit"
    )
    filename = "seat-#{@seat.id}-proposal-#{@proposal.id}.md"
    send_data body, filename: filename, type: "text/markdown; charset=utf-8", disposition: "attachment"
  end

  def upload_markdown
    authorize MaapProposal, :upload_markdown?
    markdown = read_uploaded_markdown
    if markdown.blank?
      redirect_to organization_seat_maap_proposals_path(@organization, @seat),
                  alert: "Upload a markdown file."
      return
    end

    result = MaapProposals::UploadSeatMarkdown.call(
      seat: @seat,
      proposer: current_company_teammate,
      markdown: markdown
    )

    if result.ok?
      redirect_to edit_organization_seat_maap_proposal_path(@organization, @seat, result.value),
                  notice: "Draft created from markdown upload."
    else
      redirect_to organization_seat_maap_proposals_path(@organization, @seat),
                  alert: Array(result.error).join(", ")
    end
  end

  private

  def set_seat
    @seat = Seat.for_organization(@organization)
                .includes(:title, :titles, :reports_to_seat, :team)
                .find(params[:seat_id])
  end

  def set_proposal
    @proposal = MaapProposal.for_proposable(@seat).includes(decided_by: :person).find(params[:id])
  end

  def set_related_data
    titles_scope = @organization.titles.unarchived
    if @seat.title_id.present?
      titles_scope = titles_scope.or(@organization.titles.where(id: @seat.title_id))
    end
    @titles = titles_scope.includes(:department).ordered

    @reportable_seats = Seat.for_organization(@organization)
                            .includes(:title, employment_tenures: { company_teammate: :person })
                            .order("titles.external_title ASC, seats.seat_needed_by ASC")
                            .where.not(id: @seat.id)
                            .to_a
  end

  def proposal_attributes
    params.require(:maap_proposal).permit(
      :title_id,
      :seat_needed_by,
      :job_classification,
      :team_id,
      :reports_to_seat_id,
      :reports,
      :seat_disclaimer,
      :work_environment,
      :physical_requirements,
      :travel,
      :why_needed,
      :why_now,
      :costs_risks
    ).to_h
  end

  def read_uploaded_markdown
    file = params[:markdown_file]
    return params[:markdown_body].to_s if file.blank?

    file.read.to_s
  end
end
