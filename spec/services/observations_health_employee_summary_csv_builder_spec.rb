# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObservationsHealthEmployeeSummaryCsvBuilder do
  let(:person) { create(:person, first_name: "Pat", last_name: "Lee", email: "pat@example.com") }
  let(:teammate) { create(:teammate, person: person, first_employed_at: 1.month.ago, last_terminated_at: nil) }
  let(:manager_person) { create(:person, first_name: "Mo", last_name: "Mgr", email: "mgr@example.com") }
  let(:manager_tm) { create(:teammate, person: manager_person, organization: teammate.organization, first_employed_at: 1.month.ago, last_terminated_at: nil) }
  let(:row) do
    create(
      :employment_tenure,
      company_teammate: teammate,
      company: teammate.organization,
      manager_teammate: manager_tm,
      started_at: 2.months.ago
    )
    {
      teammate: teammate,
      person: person,
      manager: manager_person,
      given: { "status" => "green", "last_published_at" => Time.zone.parse("2025-06-01"), "observations_count" => 2 },
      received: { "status" => "yellow", "last_published_at" => nil, "observations_count" => 0 },
      kudos_mix: { "band" => "healthy", "kudos_count" => 1, "constructive_count" => 0, "display_ratio" => "1:0" },
      rating_intensity: { "band" => "no_data", "less_extreme_count" => 0, "most_extreme_count" => 0, "display_ratio" => "0:0" },
      overall_status: "yellow",
      refreshed_at: Time.zone.parse("2025-06-15 10:00")
    }
  end

  it "includes headers and employee row values" do
    csv = described_class.new([row]).call
    lines = csv.lines.map(&:chomp)

    expect(lines.first).to include("Employee Name")
    expect(lines.first).to include("Given OGO Count")
    expect(lines.second).to include("Pat Lee")
    expect(lines.second).to include("pat@example.com")
    expect(lines.second).to include("Mo Mgr")
    expect(lines.second).to include("yellow")
    expect(lines.second).to include("2")
  end
end
