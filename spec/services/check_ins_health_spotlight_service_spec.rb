# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckInsHealthSpotlightService do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil) }

  let(:service) do
    described_class.new(
      organization: organization,
      current_person: person,
      current_company_teammate: teammate,
      manage_employment: true
    )
  end

  describe "#spotlight_stats_from_cache" do
    it "counts employees without cache as needing attention" do
      data = [{ teammate: teammate, person: person, cache: nil }]
      stats = service.spotlight_stats_from_cache(data)

      expect(stats[:total_employees]).to eq(1)
      expect(stats[:all_healthy]).to eq(0)
      expect(stats[:needing_attention]).to eq(1)
      expect(stats[:completion_rate]).to eq(0)
    end

    it "counts all-healthy employees when position, assignments, and aspirations are complete" do
      cache = create(
        :check_in_health_cache,
        teammate: teammate,
        organization: organization,
        payload: {
          "position" => { "category" => "green" },
          "assignments" => [{ "category" => "green" }],
          "aspirations" => [{ "category" => "green" }],
          "milestones" => { "total_required" => 0, "earned_count" => 0 }
        }
      )
      data = [{ teammate: teammate, person: person, cache: cache }]
      stats = service.spotlight_stats_from_cache(data)

      expect(stats[:all_healthy]).to eq(1)
      expect(stats[:needing_attention]).to eq(0)
    end
  end

  describe "#compact_spotlight_stats" do
    it "maps page stats to three-tier Start Here counts" do
      allow(service).to receive(:spotlight_stats_for).and_return(
        total_employees: 3,
        all_healthy: 1,
        needing_attention: 1,
        completion_rate: 50.0
      )

      stats = service.compact_spotlight_stats(nil)

      expect(stats).to eq(
        total_employees: 3,
        healthy_count: 1,
        ok_count: 1,
        concerning_count: 1
      )
    end
  end
end
