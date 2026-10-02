# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MaapProposals Seat create lifecycle", type: :service do
  let(:organization) { create(:organization) }
  let!(:title) { create(:title, company: organization, external_title: "Designer") }
  let!(:extra_title) { create(:title, company: organization, external_title: "UX Writer") }
  let(:proposer) { create(:company_teammate, :unassigned_employee, organization: organization) }
  let(:decider) { create(:company_teammate, :unassigned_employee, :maap_manager, organization: organization) }

  before { PaperTrail.enabled = false }
  after { PaperTrail.enabled = true }

  it "creates a draft seat from a submitted create proposal with additional titles" do
    draft = MaapProposals::CreateSeatCreateDraft.call(organization: organization, proposer: proposer)
    expect(draft).to be_ok
    proposal = draft.value

    update = MaapProposals::UpdateSeatEditDraft.call(
      proposal: proposal,
      attributes: {
        "title_id" => title.id,
        "additional_title_ids" => [extra_title.id],
        "seat_needed_by" => (Date.current + 2.months).iso8601,
        "job_classification" => "Hourly",
        "why_needed" => "Growth hiring"
      }
    )
    expect(update).to be_ok

    submit = MaapProposals::SubmitSeatEdit.call(proposal: proposal.reload)
    expect(submit).to be_ok

    apply = MaapProposals::ApplySeatCreate.call(proposal: proposal.reload, decided_by: decider)
    expect(apply).to be_ok

    seat = apply.value.proposable
    expect(seat).to be_a(Seat)
    expect(seat).to be_draft
    expect(seat.title_id).to eq(title.id)
    expect(seat.associated_title_ids).to contain_exactly(title.id, extra_title.id)
    expect(seat.job_classification).to eq("Hourly")
    expect(seat.why_needed).to eq("Growth hiring")
  end

  it "round-trips create markdown upload" do
    payload = MaapProposals::SeatPayload.from_hash(
      "title_id" => title.id,
      "additional_title_ids" => [extra_title.id],
      "seat_needed_by" => (Date.current + 1.month).iso8601,
      "job_classification" => "Contractor",
      "why_needed" => "From markdown"
    )
    markdown = MaapProposals::SeatMarkdownSerializer.call(
      payload: payload,
      kind: "create",
      create_key: SecureRandom.uuid
    )

    upload = MaapProposals::UploadSeatCreateMarkdown.call(
      organization: organization,
      proposer: proposer,
      markdown: markdown
    )
    expect(upload).to be_ok
    expect(upload.value.proposed_payload["why_needed"]).to eq("From markdown")
    expect(upload.value.proposed_payload["additional_title_ids"]).to eq([extra_title.id])
  end
end
