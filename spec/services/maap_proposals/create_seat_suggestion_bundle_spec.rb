# frozen_string_literal: true

require "rails_helper"

RSpec.describe MaapProposals::CreateSeatSuggestionBundle do
  let(:organization) { create(:organization, :company) }
  let(:proposer) { create(:company_teammate, :unassigned_employee, organization: organization) }
  let!(:major_level) { create(:position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: major_level, level: "1.1") }

  before do
    create(:title, company: organization, position_major_level: major_level)
  end

  it "creates a seat create draft with linked title/team/position/assignment/ability drafts" do
    result = described_class.call(
      organization: organization,
      proposer: proposer,
      bundle: {
        "seat" => {
          "why_needed" => "We need analytics that customers can use.",
          "why_now" => "Pipeline is blocked without ownership.",
          "costs_risks" => "We keep guessing and shipping the wrong insights.",
          "job_classification" => "Salaried Exempt"
        },
        "title" => {
          "mode" => "create",
          "external_title" => "Staff Data Analytics Engineer",
          "position_major_level_id" => major_level.id,
          "position_summary" => "Owns customer-facing analytics."
        },
        "team" => {
          "mode" => "create",
          "name" => "Product Insights"
        },
        "position" => {
          "position_summary" => "Level 1 analytics seat",
          "position_level_hint" => "1"
        },
        "assignments" => [
          {
            "mode" => "create",
            "title" => "Customer Analytics Owner",
            "tagline" => "Ship trusted analytics into the product",
            "energy_percentage" => 40,
            "assignment_type" => "required",
            "outcomes" => ["Customers can answer key questions without asking us"],
            "abilities" => [
              {
                "mode" => "create",
                "name" => "Analytics Product Sense",
                "description" => "Turns ambiguous questions into measurable product insights",
                "milestone_level" => 3,
                "milestone_1_examples" => [
                  "Restates a vague analytics ask into one measurable product question"
                ],
                "milestone_examples" => {
                  "3" => [
                    "Chooses instrumentation before building the dashboard",
                    "Rejects vanity metrics that will not change a product decision"
                  ]
                }
              }
            ]
          }
        ]
      }
    )

    expect(result.ok?).to eq(true), -> { Array(result.error).join(", ") }
    seat = result.value[:seat_proposal]
    expect(seat.seat_create?).to eq(true)
    expect(seat.status).to eq("draft")
    expect(seat.proposed_payload["why_needed"]).to include("analytics")
    expect(seat.proposed_payload["title_id"]).to be_nil
    expect(seat.proposed_payload["title_proposal_id"]).to be_present
    expect(seat.proposed_payload["pending_title_name"]).to eq("Staff Data Analytics Engineer")
    expect(seat.proposed_payload["team_proposal_id"]).to be_present

    roles = seat.child_proposal_links.pluck(:role)
    expect(roles).to include("title", "team", "position", "assignment", "ability")
    expect(seat.seat_apply_blockers).not_to be_empty

    ability = seat.children_for_role("ability").first
    payload = ability.proposed_payload
    expect(payload["description"]).to eq("Turns ambiguous questions into measurable product insights")
    expect(payload["milestone_1_description"]).to include("small amount of guidance")
    expect(payload["milestone_1_description"]).to include("Restates a vague analytics ask")
    expect(payload["milestone_1_description"]).not_to include("Example 1")
    expect(payload["milestone_3_description"]).to include("expert within this discipline")
    expect(payload["milestone_3_description"]).to include("Chooses instrumentation before building the dashboard")
    expect(payload["milestone_3_description"]).not_to include("Example 1")
  end
end
