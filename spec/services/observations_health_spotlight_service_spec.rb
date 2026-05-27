# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObservationsHealthSpotlightService do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  subject(:service) do
    described_class.new(
      organization: organization,
      current_person: person,
      current_company_teammate: teammate,
      manage_employment: true
    )
  end

  describe "#rows_and_spotlight_for" do
    it "builds rows from cache and maps overall green to healthy spotlight status" do
      create(
        :observation_health_cache,
        teammate: teammate,
        organization: organization,
        payload: {
          "given" => { "status" => "green", "last_published_at" => 1.day.ago.iso8601 },
          "received" => { "status" => "green", "last_published_at" => 1.day.ago.iso8601 },
          "kudos_mix" => { "band" => "healthy", "kudos_count" => 3, "constructive_count" => 1, "display_ratio" => "3:1" },
          "rating_intensity" => { "band" => "healthy", "less_extreme_count" => 6, "most_extreme_count" => 2, "display_ratio" => "3:1" },
          "overall_status" => "green"
        }
      )

      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:status]).to eq(:healthy)
      expect(row[:given]["status"]).to eq("green")
      expect(data[:spotlight_stats][:healthy_count]).to eq(1)
    end

    it "uses empty payload when cache is missing" do
      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:status]).to eq(:concerning)
      expect(row[:overall_status]).to eq("red")
    end
  end
end
