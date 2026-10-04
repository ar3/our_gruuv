# frozen_string_literal: true

# Shared show/submit/apply/reject for Title, Team, and Position create proposals.
module MaapSimpleCreateProposals
  extend ActiveSupport::Concern

  included do
    before_action :set_proposal, only: %i[show submit apply reject]
    after_action :verify_authorized
  end

  def show
    authorize @proposal
    @payload = payload_class.from_hash(@proposal.proposed_payload)
    @parent_seat_proposal = @proposal.parent_seat_create_proposal
  end

  def submit
    authorize @proposal
    result = MaapProposals::SubmitSimpleCreate.call(proposal: @proposal)
    if result.ok?
      redirect_to polymorphic_show_path, notice: "#{resource_label} create proposal submitted for review."
    else
      redirect_to polymorphic_show_path, alert: Array(result.error).join(", ")
    end
  end

  def apply
    authorize @proposal
    result = apply_service.call(
      proposal: @proposal,
      decided_by: current_company_teammate,
      decision_note: params[:decision_note]
    )
    if result.ok?
      redirect_to polymorphic_show_path, notice: "#{resource_label} created from proposal."
    else
      redirect_to polymorphic_show_path, alert: Array(result.error).join(", ")
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
                  notice: "#{resource_label} create proposal rejected."
    else
      redirect_to polymorphic_show_path, alert: Array(result.error).join(", ")
    end
  end

  private

  def set_proposal
    @proposal = proposal_scope.for_organization(@organization).find(params[:id])
  end

  def polymorphic_show_path
    public_send(show_path_helper, @organization, @proposal)
  end
end
