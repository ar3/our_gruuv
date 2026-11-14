# frozen_string_literal: true

require "rails_helper"

RSpec.describe MaapProposals::CreateAbilitySuggestionBundle do
  let(:organization) { create(:organization, :company) }
  let(:proposer) { create(:company_teammate, :unassigned_employee, organization: organization) }

  it "creates multiple ability create drafts in one confirm" do
    result = described_class.call(
      organization: organization,
      proposer: proposer,
      bundle: {
        "abilities" => [
          {
            "mode" => "create",
            "name" => "Customer Interviewing",
            "description" => "Runs interviews that surface decisions"
          },
          {
            "mode" => "create",
            "name" => "Insight Synthesis",
            "description" => "Turns interview notes into shared insights"
          }
        ]
      }
    )

    expect(result).to be_ok
    expect(result.value[:proposals].size).to eq(2)
    expect(result.value[:proposals].map { |p| p.proposed_payload["name"] }).to contain_exactly(
      "Customer Interviewing",
      "Insight Synthesis"
    )
    expect(result.value[:redirect_path]).to include("maap_ability_creates")
  end

  it "creates an ability edit draft" do
    ability = create(:ability, company: organization, name: "Facilitation", description: "Old")

    result = described_class.call(
      organization: organization,
      proposer: proposer,
      bundle: {
        "abilities" => [
          {
            "mode" => "edit",
            "ability_id" => ability.id,
            "description" => "Facilitates decisions without owning the room"
          }
        ]
      }
    )

    expect(result).to be_ok
    primary = result.value[:primary_proposal]
    expect(primary).to be_edit_kind
    expect(primary.proposable).to eq(ability)
    expect(primary.proposed_payload["description"]).to eq("Facilitates decisions without owning the room")
  end
end
