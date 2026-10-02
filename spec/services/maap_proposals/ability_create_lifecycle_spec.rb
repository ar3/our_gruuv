# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MaapProposals Ability create lifecycle", type: :service do
  let(:organization) { create(:organization) }
  let(:proposer) { create(:company_teammate, :unassigned_employee, organization: organization) }
  let(:decider) { create(:company_teammate, :unassigned_employee, :maap_manager, organization: organization) }

  before { PaperTrail.enabled = false }
  after { PaperTrail.enabled = true }

  it "round-trips create markdown via create_key and applies as early draft" do
    draft = MaapProposals::CreateAbilityCreateDraft.call(
      organization: organization,
      proposer: proposer
    )
    expect(draft).to be_ok
    proposal = draft.value
    expect(proposal.ability_create?).to be(true)

    markdown = MaapProposals::AbilityMarkdownSerializer.call(
      payload: MaapProposals::AbilityPayload.from_hash(
        "name" => "Created From MD",
        "description" => "Fresh ability",
        "milestone_1_description" => "Basics with guidance",
        "milestone_3_description" => "Independent contributor"
      ),
      kind: "create",
      create_key: proposal.create_key
    )

    upload = MaapProposals::UploadAbilityCreateMarkdown.call(
      organization: organization,
      proposer: proposer,
      markdown: markdown
    )
    expect(upload).to be_ok
    expect(upload.value.id).to eq(proposal.id)
    expect(upload.value.proposed_payload["name"]).to eq("Created From MD")

    submit = MaapProposals::SubmitAbilityEdit.call(proposal: proposal.reload)
    expect(submit).to be_ok

    apply = MaapProposals::ApplyAbilityCreate.call(
      proposal: proposal.reload,
      decided_by: decider
    )
    expect(apply).to be_ok

    ability = apply.value.proposable
    expect(ability).to be_a(Ability)
    expect(ability.name).to eq("Created From MD")
    expect(ability.description).to eq("Fresh ability")
    expect(ability.milestone_1_description).to eq("Basics with guidance")
    expect(ability.milestone_3_description).to eq("Independent contributor")
    expect(ability.semantic_version).to eq("0.0.1")
  end

  it "warns on name collision for submitted create" do
    existing = create(:ability, company: organization, name: "Taken Name")
    create_proposal = create(
      :maap_proposal,
      :ability_create,
      :submitted,
      organization: organization,
      proposer: proposer,
      proposed_payload: {
        "schema_version" => 1,
        "name" => "Taken Name",
        "description" => "desc",
        "milestone_1_description" => "m1"
      }
    )

    create_check = MaapProposals::AbilityNameUniqueness.call(
      organization: organization,
      proposed_name: create_proposal.proposed_payload["name"],
      mode: :create
    )
    expect(create_check.taken?).to be(true)
    expect(create_check.apply_name).to eq("Taken Name (duplicate)")
    expect(create_check.message).to include("(duplicate)")

    other = create(:ability, company: organization, name: "Other")
    edit_check = MaapProposals::AbilityNameUniqueness.call(
      organization: organization,
      proposed_name: existing.name,
      excluding_ability: other,
      mode: :edit
    )
    expect(edit_check.taken?).to be(true)
    expect(edit_check.message).to include("already used")
  end
end
