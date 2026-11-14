# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthNudges::ProtectFlowNudgeContextBuilder do
  it "exposes One Thing priority order aligned with the carousel builder" do
    expect(described_class::ONE_THING_PRIORITY_ORDER.size).to eq(OneOnOne::PriorityCarouselBuilder::PRIORITY_TOTAL)
    expect(described_class::ONE_THING_PRIORITY_ORDER.map { |row| row[:position] }).to eq((1..13).to_a)
  end

  it "includes one_thing_priority_order and per-person one_thing_needing_attention" do
    company = create(:organization, :company)
    teammate = create(:company_teammate, organization: company)
    create(:one_on_one_link, teammate: teammate, url: "https://example.com")

    payload = described_class.call(
      organization: company,
      people: [
        {
          teammate: teammate,
          teammate_id: teammate.id,
          name: "Alex",
          worst_status: EngagementHealth::NEEDS_ATTENTION,
          steady_count: 3,
          week_needs_work_count: 2,
          statuses: [],
          attention_items: []
        }
      ]
    )

    expect(payload[:one_thing_priority_order]).to be_present
    expect(payload[:people].sole).to have_key(:one_thing_needing_attention)
  end
end
