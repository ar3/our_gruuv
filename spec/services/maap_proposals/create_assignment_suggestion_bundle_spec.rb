# frozen_string_literal: true

require "rails_helper"

RSpec.describe MaapProposals::CreateAssignmentSuggestionBundle do
  let(:organization) { create(:organization, :company) }
  let(:proposer) { create(:company_teammate, :unassigned_employee, organization: organization) }

  it "creates an assignment create draft with nested ability create" do
    result = described_class.call(
      organization: organization,
      proposer: proposer,
      bundle: {
        "assignments" => [
          {
            "mode" => "create",
            "title" => "Pipeline Driver",
            "tagline" => "Move qualified opportunities forward",
            "outcomes" => ["Qualified pipeline grows week over week"],
            "abilities" => [
              {
                "mode" => "create",
                "name" => "Opportunity Framing",
                "description" => "Frames deals clearly",
                "milestone_level" => 3
              }
            ]
          }
        ]
      }
    )

    expect(result).to be_ok
    primary = result.value[:primary_proposal]
    expect(primary).to be_assignment_create
    expect(primary.proposed_payload["title"]).to eq("Pipeline Driver")
    ability = result.value[:proposals].find(&:ability_create?)
    expect(ability).to be_present
    expect(ability.proposed_payload["name"]).to eq("Opportunity Framing")
    expect(result.value[:redirect_path]).to include("maap_assignment_creates")
  end

  it "creates an assignment edit draft for an existing assignment" do
    assignment = create(:assignment, company: organization, title: "Demo Sourcer")

    result = described_class.call(
      organization: organization,
      proposer: proposer,
      bundle: {
        "assignments" => [
          {
            "mode" => "edit",
            "assignment_id" => assignment.id,
            "tagline" => "Clearer sourcing outcomes",
            "outcomes" => ["**(Qualified demos)** At least 8 per month"]
          }
        ]
      }
    )

    expect(result).to be_ok
    primary = result.value[:primary_proposal]
    expect(primary).to be_edit_kind
    expect(primary.proposable).to eq(assignment)
    expect(primary.proposed_payload["tagline"]).to eq("Clearer sourcing outcomes")
  end
end
