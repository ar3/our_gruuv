# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MaapProposals Position edit lifecycle", type: :service do
  let(:organization) { create(:organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { title.position_major_level.position_levels.first || create(:position_level, position_major_level: title.position_major_level, level: "1.1") }
  let!(:position) { create(:position, title: title, position_level: position_level, position_summary: "Baseline summary") }
  let!(:assignment) { create(:assignment, company: organization, title: "Ship features") }
  let(:proposer) { create(:company_teammate, :unassigned_employee, organization: organization) }
  let(:decider) { create(:company_teammate, :unassigned_employee, :maap_manager, organization: organization) }

  before { PaperTrail.enabled = false }
  after { PaperTrail.enabled = true }

  it "drafts, submits, and applies a Position edit including assignment links" do
    draft = MaapProposals::CreatePositionEditDraft.call(position: position, proposer: proposer)
    expect(draft).to be_ok
    proposal = draft.value

    update = MaapProposals::UpdatePositionEditDraft.call(
      proposal: proposal,
      attributes: {
        "position_summary" => "Owns platform reliability",
        "position_level_id" => position.position_level_id,
        "assignment_links" => [
          {
            "assignment_id" => assignment.id,
            "assignment_type" => "required",
            "energy_percentage" => 40
          }
        ]
      }
    )
    expect(update).to be_ok

    submit = MaapProposals::SubmitPositionEdit.call(proposal: proposal.reload)
    expect(submit).to be_ok

    apply = MaapProposals::ApplyPositionEdit.call(
      proposal: proposal.reload,
      decided_by: decider,
      decision_note: "Looks good"
    )
    expect(apply).to be_ok
    expect(position.reload.position_summary).to eq("Owns platform reliability")
    expect(position.position_assignments.count).to eq(1)
    link = position.position_assignments.first
    expect(link.assignment_id).to eq(assignment.id)
    expect(link.assignment_type).to eq("required")
    expect(link.min_estimated_energy).to eq(40)
    expect(proposal.reload.applied_version_type).to be_nil
  end
end
