# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProtectFlow::HeroItemLinks do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: company) }

  def create_item(category:, status:, name:, entity_type: nil, entity_id: nil)
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: company,
      level: "item",
      category: category,
      entity_type: entity_type,
      entity_id: entity_id,
      status: status,
      inputs: { "name" => name },
      computed_at: Time.current
    )
  end

  it "returns top unhealthy clarity items as deep links" do
    create_item(
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      status: EngagementHealth::NEEDS_ATTENTION,
      name: "Support Desk",
      entity_type: "Assignment",
      entity_id: 42
    )
    create_item(
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      status: EngagementHealth::WARNING,
      name: "Growth Aspiration",
      entity_type: "Aspiration",
      entity_id: 7
    )
    create_item(
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      status: EngagementHealth::HEALTHY,
      name: "Healthy Assignment",
      entity_type: "Assignment",
      entity_id: 99
    )

    people = [
      {
        teammate_id: teammate.id,
        hero: { category: EngagementHealth::CATEGORY_REQUIRED_CLARITY }
      }
    ]

    links = described_class.for_people(organization: company, people: people)[teammate.id]
    expect(links.map { |l| l[:label] }).to eq(["Support Desk", "Growth Aspiration"])
    expect(links.first[:path]).to include("/assignments/42")
    expect(links.second[:path]).to include("/aspirations/7")
  end

  it "returns empty for maintain heroes" do
    people = [{ teammate_id: teammate.id, hero: { category: "maintain" } }]
    expect(described_class.for_people(organization: company, people: people)).to eq({})
  end
end
