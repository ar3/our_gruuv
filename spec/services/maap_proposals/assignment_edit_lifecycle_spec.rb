# frozen_string_literal: true

require "rails_helper"

RSpec.describe MaapProposals::AssignmentPayload do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, :with_outcomes, company: organization) }

  describe ".from_assignment" do
    it "captures suggestable fields and outcomes" do
      payload = described_class.from_assignment(assignment)

      expect(payload.title).to eq(assignment.title)
      expect(payload.tagline).to eq(assignment.tagline)
      expect(payload.outcomes.size).to eq(3)
      expect(payload.outcomes.map { |o| o["id"] }).to match_array(assignment.assignment_outcomes.pluck(:id))
    end

    it "captures ability milestones and reliance ids" do
      ability = create(:ability, company: organization, name: "Communication")
      create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
      consumer = create(:assignment, company: organization, title: "Downstream")
      supplier = create(:assignment, company: organization, title: "Upstream")
      create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: consumer)
      create(:assignment_supply_relationship, supplier_assignment: supplier, consumer_assignment: assignment)

      payload = described_class.from_assignment(assignment.reload)
      expect(payload.ability_milestones).to eq([{ "ability_id" => ability.id, "milestone_level" => 2 }])
      expect(payload.consumer_assignment_ids).to eq([consumer.id])
      expect(payload.supplier_assignment_ids).to eq([supplier.id])
    end
  end

  describe "#same_as?" do
    it "is true for identical snapshots" do
      a = described_class.from_assignment(assignment)
      b = described_class.from_assignment(assignment.reload)
      expect(a).to be_same_as(b)
    end
  end

  describe "#validate!" do
    it "requires title and tagline" do
      payload = described_class.from_hash("title" => "", "tagline" => "", "outcomes" => [])
      expect(payload.validate!(company: organization)).to include("title is required", "tagline is required")
    end
  end
end

RSpec.describe MaapProposals::AssignmentMarkdownSerializer do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization, handbook: "Be kind") }
  let!(:outcome) do
    create(:assignment_outcome, assignment: assignment, description: "Ship clarity", outcome_type: "quantitative")
  end
  let(:payload) { MaapProposals::AssignmentPayload.from_assignment(assignment.reload) }

  it "round-trips through the deserializer including outcome ids" do
    markdown = described_class.call(
      assignment: assignment,
      payload: payload,
      based_on_semantic_version: assignment.semantic_version
    )
    expect(markdown).to include("id: #{outcome.id}")

    result = MaapProposals::AssignmentMarkdownDeserializer.call(
      markdown: markdown,
      organization: assignment.company,
      assignment: assignment
    )
    expect(result).to be_ok
    expect(result.value[:payload]).to be_same_as(payload)
    expect(result.value[:payload].outcomes.first["id"]).to eq(outcome.id)
  end

  it "round-trips ability milestones and reliance ids" do
    ability = create(:ability, company: organization, name: "Communication")
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 3)
    consumer = create(:assignment, company: organization, title: "Downstream")
    create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: consumer)
    full_payload = MaapProposals::AssignmentPayload.from_assignment(assignment.reload)

    markdown = described_class.call(
      assignment: assignment,
      payload: full_payload,
      based_on_semantic_version: assignment.semantic_version
    )
    expect(markdown).to include("## Ability milestones")
    expect(markdown).to include("ability_id: #{ability.id}")
    expect(markdown).to include("## Consumer assignments")
    expect(markdown).to include("assignment_id: #{consumer.id}")

    result = MaapProposals::AssignmentMarkdownDeserializer.call(
      markdown: markdown,
      organization: assignment.company,
      assignment: assignment
    )
    expect(result).to be_ok
    expect(result.value[:payload].ability_milestones).to eq(full_payload.ability_milestones)
    expect(result.value[:payload].consumer_assignment_ids).to eq([consumer.id])
  end
end

RSpec.describe MaapProposals::CreateAssignmentEditDraft do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:proposer) { create(:teammate, :unassigned_employee, organization: organization) }

  it "creates a draft proposal from the live assignment" do
    result = described_class.call(assignment: assignment, proposer: proposer)
    expect(result).to be_ok
    expect(result.value).to be_draft
    expect(result.value.proposable).to eq(assignment)
    expect(result.value.proposed_payload["title"]).to eq(assignment.title)
  end
end

RSpec.describe MaapProposals::SubmitAssignmentEdit do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization, title: "Live Title", tagline: "Live tagline") }
  let(:proposer) { create(:teammate, :unassigned_employee, organization: organization) }

  it "rejects unchanged drafts" do
    draft = MaapProposals::CreateAssignmentEditDraft.call(assignment: assignment, proposer: proposer).value
    result = described_class.call(proposal: draft)
    expect(result).not_to be_ok
    expect(Array(result.error).join).to include("no changes")
  end

  it "submits changed drafts" do
    draft = MaapProposals::CreateAssignmentEditDraft.call(assignment: assignment, proposer: proposer).value
    MaapProposals::UpdateAssignmentEditDraft.call(
      proposal: draft,
      attributes: { "title" => "Changed Title", "tagline" => assignment.tagline }
    )
    result = described_class.call(proposal: draft.reload)
    expect(result).to be_ok
    expect(result.value).to be_submitted
  end
end

RSpec.describe MaapProposals::ApplyAssignmentEdit do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization, title: "Live Title", tagline: "Live tagline", semantic_version: "1.0.0") }
  let(:proposer) { create(:teammate, :unassigned_employee, organization: organization) }
  let(:editor) { create(:teammate, :unassigned_employee, :maap_manager, organization: organization) }

  it "applies a submitted proposal and bumps the version" do
    draft = MaapProposals::CreateAssignmentEditDraft.call(assignment: assignment, proposer: proposer).value
    MaapProposals::UpdateAssignmentEditDraft.call(
      proposal: draft,
      attributes: { "title" => "New Title", "tagline" => "New tagline" },
      outcomes: [{ "description" => "Ship clarity", "outcome_type" => "quantitative" }]
    )
    MaapProposals::SubmitAssignmentEdit.call(proposal: draft.reload)

    result = described_class.call(
      proposal: draft.reload,
      decided_by: editor,
      version_type: "clarifying"
    )

    expect(result).to be_ok
    assignment.reload
    expect(assignment.title).to eq("New Title")
    expect(assignment.tagline).to eq("New tagline")
    expect(assignment.semantic_version).to eq("1.1.0")
    expect(assignment.assignment_outcomes.map(&:description)).to eq(["Ship clarity"])
    expect(result.value).to be_applied
    expect(result.value.applied_version_type).to eq("clarifying")
    expect(result.value.baseline_payload["title"]).to eq("Live Title")
    expect(result.value.baseline_payload["tagline"]).to eq("Live tagline")
  end

  it "updates existing outcomes by id so renames preserve side fields" do
    outcome = create(
      :assignment_outcome,
      assignment: assignment,
      description: "Old name",
      outcome_type: "quantitative",
      progress_report_url: "https://example.com/report",
      management_relationship_filter: "direct_employee"
    )

    draft = MaapProposals::CreateAssignmentEditDraft.call(assignment: assignment, proposer: proposer).value
    MaapProposals::UpdateAssignmentEditDraft.call(
      proposal: draft,
      attributes: { "title" => assignment.title, "tagline" => "Slightly clearer tagline" },
      outcomes: [{ "id" => outcome.id, "description" => "Renamed outcome", "outcome_type" => "sentiment" }]
    )
    MaapProposals::SubmitAssignmentEdit.call(proposal: draft.reload)

    result = described_class.call(
      proposal: draft.reload,
      decided_by: editor,
      version_type: "clarifying"
    )

    expect(result).to be_ok
    outcome.reload
    expect(assignment.assignment_outcomes.pluck(:id)).to eq([outcome.id])
    expect(outcome.description).to eq("Renamed outcome")
    expect(outcome.outcome_type).to eq("sentiment")
    expect(outcome.progress_report_url).to eq("https://example.com/report")
    expect(outcome.management_relationship_filter).to eq("direct_employee")
  end

  it "applies ability milestones and reliance, skipping missing association targets with warnings" do
    ability = create(:ability, company: organization, name: "Communication")
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
    consumer = create(:assignment, company: organization, title: "Downstream")
    create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: consumer)

    draft = MaapProposals::CreateAssignmentEditDraft.call(assignment: assignment, proposer: proposer).value
    new_ability = create(:ability, company: organization, name: "Mentorship")
    new_consumer = create(:assignment, company: organization, title: "New Downstream")
    MaapProposals::UpdateAssignmentEditDraft.call(
      proposal: draft,
      attributes: { "title" => assignment.title, "tagline" => assignment.tagline },
      ability_milestones: [
        { "ability_id" => new_ability.id, "milestone_level" => 4 },
        { "ability_id" => 9_999_999, "milestone_level" => 2 }
      ],
      consumer_assignment_ids: [new_consumer.id, 9_999_998],
      supplier_assignment_ids: []
    )
    MaapProposals::SubmitAssignmentEdit.call(proposal: draft.reload)

    result = described_class.call(
      proposal: draft.reload,
      decided_by: editor,
      version_type: "insignificant"
    )

    expect(result).to be_ok
    assignment.reload
    expect(assignment.assignment_abilities.pluck(:ability_id, :milestone_level)).to eq([[new_ability.id, 4]])
    expect(assignment.consumer_assignments.pluck(:id)).to eq([new_consumer.id])
    expect(result.value.decision_warnings.join).to include("9999999")
    expect(result.value.decision_warnings.join).to include("9999998")
  end
end

RSpec.describe MaapProposals::RejectAssignmentEdit do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization, title: "Live Title", tagline: "Live tagline") }
  let(:proposer) { create(:teammate, :unassigned_employee, organization: organization) }
  let(:editor) { create(:teammate, :unassigned_employee, :maap_manager, organization: organization) }

  it "rejects a submitted proposal and stores the live assignment baseline" do
    draft = MaapProposals::CreateAssignmentEditDraft.call(assignment: assignment, proposer: proposer).value
    MaapProposals::UpdateAssignmentEditDraft.call(
      proposal: draft,
      attributes: { "title" => "Rejected Title", "tagline" => assignment.tagline }
    )
    MaapProposals::SubmitAssignmentEdit.call(proposal: draft.reload)

    result = described_class.call(proposal: draft.reload, decided_by: editor, decision_note: "Not yet")

    expect(result).to be_ok
    expect(result.value).to be_rejected
    expect(result.value.decision_note).to eq("Not yet")
    expect(result.value.baseline_payload["title"]).to eq("Live Title")
    expect(assignment.reload.title).to eq("Live Title")
  end
end
