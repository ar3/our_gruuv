# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MaapProposals create lifecycle", type: :service do
  let(:organization) { create(:organization) }
  let(:proposer) { create(:company_teammate, :unassigned_employee, organization: organization) }
  let(:decider) { create(:company_teammate, :unassigned_employee, :maap_manager, organization: organization) }

  before { PaperTrail.enabled = false }
  after { PaperTrail.enabled = true }

  it "round-trips create markdown via create_key and applies associations" do
    ability = create(:ability, company: organization, name: "Facilitation")
    consumer = create(:assignment, company: organization, title: "Consumer A")

    draft = MaapProposals::CreateAssignmentCreateDraft.call(
      organization: organization,
      proposer: proposer
    )
    expect(draft).to be_ok
    proposal = draft.value

    markdown = MaapProposals::AssignmentMarkdownSerializer.call(
      payload: MaapProposals::AssignmentPayload.from_hash(
        "title" => "Created From MD",
        "tagline" => "Fresh start",
        "required_activities" => "Do the thing",
        "handbook" => "Guide",
        "outcomes" => [{ "description" => "Outcome one", "outcome_type" => "quantitative" }],
        "ability_milestones" => [{ "ability_id" => ability.id, "milestone_level" => 3 }],
        "consumer_assignment_ids" => [consumer.id],
        "supplier_assignment_ids" => []
      ),
      kind: "create",
      create_key: proposal.create_key
    )

    upload = MaapProposals::UploadAssignmentCreateMarkdown.call(
      organization: organization,
      proposer: proposer,
      markdown: markdown
    )
    expect(upload).to be_ok
    expect(upload.value.id).to eq(proposal.id)
    expect(upload.value.proposed_payload["title"]).to eq("Created From MD")

    submit = MaapProposals::SubmitAssignmentEdit.call(proposal: proposal.reload)
    expect(submit).to be_ok

    apply = MaapProposals::ApplyAssignmentCreate.call(
      proposal: proposal.reload,
      decided_by: decider
    )
    expect(apply).to be_ok

    assignment = apply.value.proposable
    expect(assignment.title).to eq("Created From MD")
    expect(assignment.assignment_outcomes.count).to eq(1)
    expect(assignment.assignment_abilities.find_by(ability: ability).milestone_level).to eq(3)
    expect(assignment.consumer_assignments).to include(consumer)
  end

  it "warns on title collision for submitted create and edit shows" do
    existing = create(:assignment, company: organization, title: "Taken Title")
    create_proposal = create(
      :maap_proposal,
      :create_kind,
      :submitted,
      organization: organization,
      proposer: proposer,
      proposed_payload: {
        "schema_version" => 2,
        "title" => "Taken Title",
        "tagline" => "tag",
        "outcomes" => [],
        "ability_milestones" => [],
        "consumer_assignment_ids" => [],
        "supplier_assignment_ids" => []
      }
    )

    create_check = MaapProposals::TitleUniqueness.call(
      organization: organization,
      proposed_title: create_proposal.proposed_title,
      mode: :create
    )
    expect(create_check.taken?).to be(true)
    expect(create_check.apply_title).to eq("Taken Title (duplicate)")
    expect(create_check.message).to include("(duplicate)")

    other = create(:assignment, company: organization, title: "Other")
    edit_check = MaapProposals::TitleUniqueness.call(
      organization: organization,
      proposed_title: existing.title,
      excluding_assignment: other,
      mode: :edit
    )
    expect(edit_check.taken?).to be(true)
    expect(edit_check.message).to include("already used")
  end
end
