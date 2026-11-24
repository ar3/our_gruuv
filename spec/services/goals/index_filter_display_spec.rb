# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::IndexFilterDisplay do
  let(:organization) { create(:organization, :company, name: "Acme Co") }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:department) { create(:department, company: organization, name: "Engineering") }
  let(:team) { create(:team, company: organization, name: "Platform") }

  def labels_for(params)
    described_class.pills(params: params, organization: organization).map(&:label)
  end

  it "returns human owner / type / status / timeframe pills and never raw Type_id tokens" do
    labels = labels_for(
      owner_keys: ["Company_#{organization.id}", "Department_#{department.id}", "Team_#{team.id}"],
      goal_type: %w[progressive_outcome quantitative_key_result],
      status: %w[draft active],
      timeframe: "now",
      view: "table",
      sort: "title"
    )

    expect(labels).to include("Company: Acme Co")
    expect(labels).to include("Department: Engineering")
    expect(labels).to include("Team: Platform")
    expect(labels).to include("Type: OG3 Progressive Outcome")
    expect(labels).to include("Type: Quantitative Key Result")
    expect(labels).to include("Status: Draft")
    expect(labels).to include("Status: Active")
    expect(labels).to include("Timeframe: Now")
    expect(labels.join).not_to match(/Company_\d+|Department_\d+|Team_\d+/)
    expect(labels.join).not_to include("Customized view")
  end

  it "labels special owner filters and skips view/sort chrome" do
    labels = labels_for(owner_id: "my_relevant_goals", view: "cards", sort: "created_at", direction: "desc")

    expect(labels).to eq(["My relevant goals"])
  end

  it "labels a single teammate owner without exposing the Type_id token" do
    labels = labels_for(owner_id: "CompanyTeammate_#{teammate.id}")

    expect(labels.length).to eq(1)
    expect(labels.first).to start_with("Teammate:")
    expect(labels.first).not_to include("CompanyTeammate_")
  end
end
