# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MaapProposals Seat edit lifecycle", type: :service do
  let(:organization) { create(:organization) }
  let(:title) { create(:title, company: organization, external_title: "Designer") }
  let(:seat) do
    create(
      :seat,
      title: title,
      seat_needed_by: Date.current + 1.month,
      job_classification: "Salaried Exempt",
      why_needed: "Original need"
    )
  end
  let(:proposer) { create(:company_teammate, :unassigned_employee, organization: organization) }
  let(:decider) { create(:company_teammate, :unassigned_employee, :maap_manager, organization: organization) }

  before { PaperTrail.enabled = false }
  after { PaperTrail.enabled = true }

  it "round-trips edit markdown and applies without version bump" do
    draft = MaapProposals::CreateSeatEditDraft.call(seat: seat, proposer: proposer)
    expect(draft).to be_ok
    proposal = draft.value

    markdown = MaapProposals::SeatMarkdownSerializer.call(
      seat: seat,
      payload: MaapProposals::SeatPayload.from_hash(
        MaapProposals::SeatPayload.from_seat(seat).to_h.merge(
          "why_needed" => "Updated need from MD",
          "job_classification" => "Contractor"
        )
      ),
      kind: "edit"
    )

    upload = MaapProposals::UploadSeatMarkdown.call(
      seat: seat,
      proposer: proposer,
      markdown: markdown
    )
    expect(upload).to be_ok
    expect(upload.value.proposed_payload["why_needed"]).to eq("Updated need from MD")

    submit = MaapProposals::SubmitSeatEdit.call(proposal: upload.value.reload)
    expect(submit).to be_ok

    apply = MaapProposals::ApplySeatEdit.call(
      proposal: upload.value.reload,
      decided_by: decider
    )
    expect(apply).to be_ok
    expect(apply.value.applied_version_type).to be_nil
    expect(seat.reload.why_needed).to eq("Updated need from MD")
    expect(seat.job_classification).to eq("Contractor")
  end
end
