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
    it "counts employees without Gruuv Health data as needs attention" do
      data = [{ teammate: teammate, person: person, cache: nil, engagement_health_records: [] }]
      stats = service.spotlight_stats_from_cache(data)

      expect(stats[:total_employees]).to eq(1)
      expect(stats[:healthy_count]).to eq(0)
      expect(stats[:warning_count]).to eq(0)
      expect(stats[:needs_attention_count]).to eq(1)
      expect(stats[:ok_percentage]).to eq(0)
    end

    it "counts employees by required clarity rollup status" do
      engagement_health_records = [
        EngagementHealthStatus.create!(
          teammate: teammate,
          organization: organization,
          level: "category",
          category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          status: EngagementHealth::HEALTHY,
          inputs: { "item_count" => 0, "empty_reason" => "no_required_items_vacuously_healthy" },
          computed_at: Time.current
        )
      ]
      data = [{ teammate: teammate, person: person, cache: nil, engagement_health_records: engagement_health_records }]
      stats = service.spotlight_stats_from_cache(data)

      expect(stats[:healthy_count]).to eq(1)
      expect(stats[:warning_count]).to eq(0)
      expect(stats[:needs_attention_count]).to eq(0)
      expect(stats[:ok_percentage]).to eq(100.0)
    end

    it "counts ok percentage as healthy plus at risk" do
      at_risk_teammate = create(:teammate, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
      needs_attention_teammate = create(:teammate, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)

      [
        [teammate, EngagementHealth::HEALTHY],
        [at_risk_teammate, EngagementHealth::WARNING],
        [needs_attention_teammate, EngagementHealth::NEEDS_ATTENTION]
      ].each do |tm, status|
        EngagementHealthStatus.create!(
          teammate: tm,
          organization: organization,
          level: "category",
          category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          status: status,
          inputs: {},
          computed_at: Time.current
        )
      end

      data = [
        { teammate: teammate, person: teammate.person, cache: nil, engagement_health_records: EngagementHealthStatus.where(teammate: teammate).to_a },
        { teammate: at_risk_teammate, person: at_risk_teammate.person, cache: nil, engagement_health_records: EngagementHealthStatus.where(teammate: at_risk_teammate).to_a },
        { teammate: needs_attention_teammate, person: needs_attention_teammate.person, cache: nil, engagement_health_records: EngagementHealthStatus.where(teammate: needs_attention_teammate).to_a }
      ]
      stats = service.spotlight_stats_from_cache(data)

      expect(stats[:healthy_count]).to eq(1)
      expect(stats[:warning_count]).to eq(1)
      expect(stats[:needs_attention_count]).to eq(1)
      expect(stats[:ok_percentage]).to eq(66.7)
    end
  end

  describe "#paginated_index_data" do
    it "loads only the requested page of teammates" do
      30.times do
        tm = create(:teammate, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
        EngagementHealthStatus.create!(
          teammate: tm,
          organization: organization,
          level: "category",
          category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          status: EngagementHealth::HEALTHY,
          inputs: {},
          computed_at: Time.current
        )
      end

      page1 = service.paginated_index_data("everyone", page: 1, items: 25)
      page2 = service.paginated_index_data("everyone", page: 2, items: 25)

      expect(page1[:total_count]).to eq(31)
      expect(page1[:rows].size).to eq(25)
      expect(page2[:rows].size).to eq(6)
      expect(page1[:spotlight_stats][:total_employees]).to eq(31)
      expect(page1[:rows].first).to include(:manager_teammate)
    end
  end

  describe "#spotlight_stats_for" do
    it "counts rollup statuses without loading item-level engagement health rows" do
      allow(service).to receive(:filtered_teammate_ids).and_return([teammate.id])

      EngagementHealthStatus.create!(
        teammate: teammate,
        organization: organization,
        level: "category",
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        status: EngagementHealth::HEALTHY,
        inputs: {},
        computed_at: Time.current
      )

      expect(CheckInsHealthEngagementHealthSupport).not_to receive(:records_by_teammate_id)

      stats = service.spotlight_stats_for("just_me")
      expect(stats[:healthy_count]).to eq(1)
    end

    it "counts unique teammates when multiple active employment tenures inflate pluck" do
      manager_person = create(:person)
      manager = create(:teammate, organization: organization, person: manager_person, first_employed_at: 1.month.ago, last_terminated_at: nil)
      report = create(:teammate, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
      tenure = create(:employment_tenure, company: organization, company_teammate: report, manager_teammate: manager)
      duplicate_tenure = tenure.dup
      duplicate_tenure.save(validate: false)

      EngagementHealthStatus.create!(
        teammate: report,
        organization: organization,
        level: "category",
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        status: EngagementHealth::HEALTHY,
        inputs: {},
        computed_at: Time.current
      )

      mgr_service = described_class.new(
        organization: organization,
        current_person: manager_person,
        current_company_teammate: manager,
        manage_employment: false
      )

      scope = mgr_service.filtered_teammates("my_direct_employees")
      expect(scope.count).to eq(1)
      expect(scope.pluck(:id).size).to be > 1

      stats = mgr_service.spotlight_stats_for("my_direct_employees")
      expect(stats[:total_employees]).to eq(1)
      expect(stats[:healthy_count]).to eq(1)
    end
  end

  describe "#compact_spotlight_stats" do
    it "maps page stats to three-tier Start Here counts" do
      allow(service).to receive(:spotlight_stats_for).and_return(
        total_employees: 4,
        healthy_count: 1,
        warning_count: 1,
        needs_attention_count: 2,
        ok_percentage: 50.0
      )

      stats = service.compact_spotlight_stats(nil)

      expect(stats).to eq(
        total_employees: 4,
        healthy_count: 1,
        ok_count: 1,
        concerning_count: 2
      )
    end
  end
end
