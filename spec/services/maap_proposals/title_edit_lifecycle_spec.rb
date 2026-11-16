# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MaapProposals Title edit lifecycle", type: :service do
  let(:organization) { create(:organization) }
  let!(:title) { create(:title, company: organization, external_title: "Engineer") }
  let(:proposer) { create(:company_teammate, :unassigned_employee, organization: organization) }
  let(:decider) { create(:company_teammate, :unassigned_employee, :maap_manager, organization: organization) }

  before { PaperTrail.enabled = false }
  after { PaperTrail.enabled = true }

  it "drafts, submits, and applies a Title edit without version bump" do
    draft = MaapProposals::CreateTitleEditDraft.call(title: title, proposer: proposer)
    expect(draft).to be_ok
    proposal = draft.value

    update = MaapProposals::UpdateTitleEditDraft.call(
      proposal: proposal,
      attributes: { "external_title" => "Staff Engineer", "position_summary" => "Owns platform reliability" }
    )
    expect(update).to be_ok

    submit = MaapProposals::SubmitTitleEdit.call(proposal: proposal.reload)
    expect(submit).to be_ok

    apply = MaapProposals::ApplyTitleEdit.call(
      proposal: proposal.reload,
      decided_by: decider,
      decision_note: "Looks good"
    )
    expect(apply).to be_ok
    expect(title.reload.external_title).to eq("Staff Engineer")
    expect(title.position_summary).to eq("Owns platform reliability")
    expect(proposal.reload.applied_version_type).to be_nil
  end
end
