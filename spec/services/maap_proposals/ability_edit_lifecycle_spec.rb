# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MaapProposals ability edit lifecycle", type: :service do
  let(:organization) { create(:organization) }
  let(:ability) do
    create(
      :ability,
      company: organization,
      name: "Coaching",
      description: "Grow others",
      milestone_1_description: "Can coach with a script",
      semantic_version: "2.0.0"
    )
  end
  let(:proposer) { create(:company_teammate, :unassigned_employee, organization: organization) }
  let(:decider) { create(:company_teammate, :unassigned_employee, :maap_manager, organization: organization) }

  before { PaperTrail.enabled = false }
  after { PaperTrail.enabled = true }

  it "round-trips markdown and applies with version bump" do
    draft = MaapProposals::CreateAbilityEditDraft.call(ability: ability, proposer: proposer)
    expect(draft).to be_ok
    proposal = draft.value

    markdown = MaapProposals::AbilityMarkdownSerializer.call(
      ability: ability,
      payload: MaapProposals::AbilityPayload.from_hash(
        draft.value.proposed_payload.merge(
          "name" => "Coaching Plus",
          "milestone_2_description" => "Can coach without a script"
        )
      ),
      based_on_semantic_version: ability.semantic_version
    )

    upload = MaapProposals::UploadAbilityMarkdown.call(
      ability: ability,
      proposer: proposer,
      markdown: markdown
    )
    expect(upload).to be_ok

    submit = MaapProposals::SubmitAbilityEdit.call(proposal: upload.value)
    expect(submit).to be_ok

    apply = MaapProposals::ApplyAbilityEdit.call(
      proposal: upload.value.reload,
      decided_by: decider,
      version_type: "fundamental"
    )
    expect(apply).to be_ok
    expect(ability.reload.name).to eq("Coaching Plus")
    expect(ability.milestone_2_description).to include("without a script")
    expect(ability.semantic_version).to eq("3.0.0")
  end

  it "warns when proposed name collides with another ability" do
    create(:ability, company: organization, name: "Taken Name", milestone_1_description: "x")
    check = MaapProposals::AbilityNameUniqueness.call(
      organization: organization,
      proposed_name: "Taken Name",
      excluding_ability: ability
    )
    expect(check.taken?).to be(true)
    expect(check.message).to include("already used")
  end
end
