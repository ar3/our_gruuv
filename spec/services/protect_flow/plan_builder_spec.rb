# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProtectFlow::PlanBuilder do
  let(:company) { create(:organization, :company) }
  let(:manager) { create(:company_teammate, organization: company) }
  let(:report) { create(:company_teammate, organization: company) }
  let(:person) { manager.person }
  let(:store) { ProtectFlow::WeekSnapshotStore.for(person: person, organization: company) }

  def create_category_status(teammate:, category:, status:)
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: company,
      level: "category",
      category: category,
      status: status,
      inputs: {},
      computed_at: Time.current
    )
  end

  def seed_all_categories(teammate, clarity_status:)
    EngagementHealth::CATEGORIES.each do |category|
      status = category == EngagementHealth::CATEGORY_REQUIRED_CLARITY ? clarity_status : EngagementHealth::HEALTHY
      create_category_status(teammate: teammate, category: category, status: status)
    end
  end

  before do
    create(:employment_tenure, company_teammate: report, company: company, manager_teammate: manager)
  end

  describe ".call" do
    it "returns empty people when teammates is empty" do
      plan = described_class.call(
        organization: company,
        week_store: store,
        teammates: []
      )

      expect(plan[:people]).to eq([])
      expect(plan[:progress][:people_count]).to eq(0)
    end

    it "builds a hero from the worst One Thing-aligned unhealthy category" do
      create_category_status(
        teammate: report,
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        status: EngagementHealth::NEEDS_ATTENTION
      )
      create_category_status(
        teammate: report,
        category: EngagementHealth::CATEGORY_OGO_RECEIVED,
        status: EngagementHealth::WARNING
      )
      EngagementHealth::CATEGORIES.each do |category|
        next if category.in?([EngagementHealth::CATEGORY_REQUIRED_CLARITY, EngagementHealth::CATEGORY_OGO_RECEIVED])

        create_category_status(teammate: report, category: category, status: EngagementHealth::HEALTHY)
      end

      plan = described_class.call(organization: company, week_store: store, teammates: [report])
      person_plan = plan[:people].sole

      expect(person_plan[:hero][:category]).to eq(EngagementHealth::CATEGORY_REQUIRED_CLARITY)
      expect(person_plan[:hero][:short_title]).to eq("Clarity Check-ins")
      expect(person_plan[:secondary].map { |a| a[:category] }).to eq([EngagementHealth::CATEGORY_OGO_RECEIVED])
      expect(person_plan[:hero][:path]).to include("check_ins")
      expect(plan[:historical]).to be(false)
    end

    it "uses a maintain hero when all categories are healthy" do
      seed_all_categories(report, clarity_status: EngagementHealth::HEALTHY)

      plan = described_class.call(organization: company, week_store: store, teammates: [report])
      person_plan = plan[:people].sole

      expect(person_plan[:hero][:category]).to eq("maintain")
      expect(person_plan[:secondary]).to be_empty
      expect(person_plan[:clear_items].size).to eq(EngagementHealth::CATEGORIES.size)
    end

    it "tracks progress from week-start snapshot when health improves (no manual complete)" do
      seed_all_categories(report, clarity_status: EngagementHealth::NEEDS_ATTENTION)

      plan = described_class.call(organization: company, week_store: store, teammates: [report])
      expect(plan[:progress][:start_unhealthy_count]).to eq(1)
      expect(plan[:progress][:current_unhealthy_count]).to eq(1)

      EngagementHealthStatus.find_by!(
        teammate: report,
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        level: "category"
      ).update!(status: EngagementHealth::HEALTHY)

      plan2 = described_class.call(organization: company, week_store: store, teammates: [report])
      expect(plan2[:progress][:start_unhealthy_count]).to eq(1)
      expect(plan2[:progress][:current_unhealthy_count]).to eq(0)
      expect(plan2[:progress][:improved_vector_count]).to eq(1)
      expect(plan2[:people].sole[:clear_items].map { |r| r[:category] }).to include(EngagementHealth::CATEGORY_REQUIRED_CLARITY)
      expect(plan2[:people].sole[:clear_items].find { |r| r[:category] == EngagementHealth::CATEGORY_REQUIRED_CLARITY }[:cleared]).to be(true)
    end

    it "closes the prior week and allows browsing history" do
      seed_all_categories(report, clarity_status: EngagementHealth::NEEDS_ATTENTION)
      prior_monday = (Date.current.beginning_of_week(:monday) - 7.days).iso8601
      prior_baseline = {
        report.id.to_s => EngagementHealth::CATEGORIES.index_with { EngagementHealth::NEEDS_ATTENTION }
      }

      prefs = UserPreference.for_person(person)
      prefs.update_preference(
        "protect_flow_weeks_v1_org_#{company.id}",
        {
          "weeks" => {
            prior_monday => {
              "week_start" => prior_monday,
              "closed" => false,
              "start_baseline" => prior_baseline,
              "end_baseline" => nil
            }
          }
        }
      )

      plan = described_class.call(organization: company, week_store: store, teammates: [report])
      expect(plan[:available_weeks].size).to be >= 2

      prior = plan[:available_weeks].find { |w| w[:week_start] == prior_monday }
      expect(prior).to be_present
      expect(prior[:closed]).to be(true)
      expect(prior[:end_baseline]).to be_present

      historical = described_class.call(
        organization: company,
        week_store: store,
        teammates: [report],
        week_start: prior_monday
      )
      expect(historical[:historical]).to be(true)
      expect(historical[:week_start]).to eq(prior_monday)
    end
  end
end
