# frozen_string_literal: true

class Organizations::MaapSeatCreatesController < Organizations::OrganizationNamespaceBaseController
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
      .seat_creates
      .for_organization(@organization)
      .with_statuses(@selected_statuses)
      .created_first
      .includes(proposer: :person, proposable: :title)
  end

  def markdown_template
    authorize MaapProposal, :markdown_template?
    create_key = SecureRandom.uuid
    payload = MaapProposals::SeatPayload.blank_for_create(company: @organization)
    body = MaapProposals::SeatMarkdownSerializer.call(
      payload: payload,
      kind: "create",
      create_key: create_key
    )
    send_data body,
              filename: "seat-create-proposal-template.md",
              type: "text/markdown; charset=utf-8",
              disposition: "attachment"
  end

  def new
    authorize MaapProposal
    result = MaapProposals::CreateSeatCreateDraft.call(
      organization: @organization,
      proposer: current_company_teammate
    )
    if result.ok?
      redirect_to edit_organization_maap_seat_create_path(@organization, result.value),
                  notice: "Draft Seat create proposal started. Edit and submit when ready."
    else
      redirect_to organization_maap_seat_creates_path(@organization),
                  alert: Array(result.error).join(", ")
    end
  end

  def show
    authorize @proposal
    @payload = MaapProposals::SeatPayload.from_hash(@proposal.proposed_payload)
    @diff_baseline = if @proposal.baseline_payload.present?
      MaapProposals::SeatPayload.from_hash(@proposal.baseline_payload)
    else
      MaapProposals::SeatPayload.empty
    end
    @field_diffs = MaapProposals::SeatDiffBuilder.call(
      before: @diff_baseline,
      after: @payload
    )
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
      redirect_to organization_maap_seat_create_path(@organization, @proposal),
                  notice: "Draft Seat create proposal updated."
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
    redirect_to organization_maap_seat_creates_path(@organization),
                notice: "Seat create proposal deleted."
  end

  def submit
    authorize @proposal
    result = MaapProposals::SubmitSeatEdit.call(proposal: @proposal)
    if result.ok?
      redirect_to organization_maap_seat_create_path(@organization, @proposal),
                  notice: "Seat create proposal submitted for review."
    else
      redirect_to organization_maap_seat_create_path(@organization, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def apply
    authorize @proposal
    result = MaapProposals::ApplySeatCreate.call(
      proposal: @proposal,
      decided_by: current_company_teammate,
      decision_note: params[:decision_note]
    )
    if result.ok?
      seat = result.value.proposable
      redirect_to organization_seat_path(@organization, seat),
                  notice: "Seat created from proposal."
    else
      redirect_to organization_maap_seat_create_path(@organization, @proposal),
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
      redirect_to organization_maap_seat_creates_path(@organization),
                  notice: "Seat create proposal rejected."
    else
      redirect_to organization_maap_seat_create_path(@organization, @proposal),
                  alert: Array(result.error).join(", ")
    end
  end

  def markdown
    authorize @proposal
    payload = MaapProposals::SeatPayload.from_hash(@proposal.proposed_payload)
    body = MaapProposals::SeatMarkdownSerializer.call(
      payload: payload,
      kind: "create",
      create_key: @proposal.create_key
    )
    filename = "seat-create-proposal-#{@proposal.id}.md"
    send_data body, filename: filename, type: "text/markdown; charset=utf-8", disposition: "attachment"
  end

  def upload_markdown
    authorize MaapProposal, :upload_markdown?
    markdown = read_uploaded_markdown
    if markdown.blank?
      redirect_to organization_maap_seat_creates_path(@organization),
                  alert: "Upload a markdown file."
      return
    end

    result = MaapProposals::UploadSeatCreateMarkdown.call(
      organization: @organization,
      proposer: current_company_teammate,
      markdown: markdown
    )

    if result.ok?
      redirect_to edit_organization_maap_seat_create_path(@organization, result.value),
                  notice: "Draft Seat create proposal created from markdown upload."
    else
      redirect_to organization_maap_seat_creates_path(@organization),
                  alert: Array(result.error).join(", ")
    end
  end

  private

  def set_proposal
    @proposal = policy_scope(MaapProposal)
      .seat_creates
      .for_organization(@organization)
      .includes(decided_by: :person, proposable: :title)
      .find(params[:id])
  end

  def set_related_data
    @titles = @organization.titles.unarchived.includes(:department).ordered
    @reportable_seats = Seat.for_organization(@organization)
                            .includes(:title, employment_tenures: { company_teammate: :person })
                            .order("titles.external_title ASC, seats.seat_needed_by ASC")
                            .to_a
  end

  def proposal_attributes
    attrs = params.require(:maap_proposal).permit(
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
      :costs_risks,
      additional_title_ids: []
    ).to_h
    attrs["additional_title_ids"] = Array(attrs["additional_title_ids"]).reject(&:blank?)
    attrs
  end

  def read_uploaded_markdown
    file = params[:markdown_file]
    return params[:markdown_body].to_s if file.blank?

    file.read.to_s
  end
end
