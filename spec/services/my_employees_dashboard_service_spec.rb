# frozen_string_literal: true

require "rails_helper"

RSpec.describe MyEmployeesDashboardService do
  let(:company) { create(:organization, :company) }
  let(:manager) { create(:company_teammate, organization: company) }
  let(:report) { create(:company_teammate, organization: company) }

  def create_healthy_clarity_item(teammate:, entity_type:, entity_id:, name:)
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: company,
      level: "item",
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      entity_type: entity_type,
      entity_id: entity_id,
      status: EngagementHealth::HEALTHY,
      inputs: { "name" => name },
      computed_at: Time.current
    )
  end

  describe ".summary" do
    it "returns zeros when manager teammate is nil" do
      s = described_class.summary(manager_teammate: nil, organization: company)
      expect(s[:direct_report_count]).to eq(0)
      expect(s[:crystal_clear_count]).to eq(0)
      expect(s[:overall_pct]).to eq(0.0)
    end

    it "returns zeros when manager has no direct reports" do
      s = described_class.summary(manager_teammate: manager, organization: company)
      expect(s[:direct_report_count]).to eq(0)
    end

    context "with one direct report" do
      before do
        create(:employment_tenure, company_teammate: report, company: company, manager_teammate: manager)
      end

      it "counts direct reports and averages 0% healthy without engagement health rows" do
        s = described_class.summary(manager_teammate: manager, organization: company)
        expect(s[:direct_report_count]).to eq(1)
        expect(s[:crystal_clear_count]).to eq(0)
        expect(s[:overall_pct]).to eq(0.0)
        expect(s[:pill_class]).to include("bg-danger")
      end

      it "counts fully healthy and success pill when all required clarity items are healthy" do
        create_healthy_clarity_item(teammate: report, entity_type: "Position", entity_id: 1, name: "Engineer")
        create_healthy_clarity_item(teammate: report, entity_type: "Assignment", entity_id: 2, name: "Support")
        create_healthy_clarity_item(teammate: report, entity_type: "Aspiration", entity_id: 3, name: "Growth")

        s = described_class.summary(manager_teammate: manager, organization: company)
        expect(s[:crystal_clear_count]).to eq(1)
        expect(s[:overall_pct]).to eq(100.0)
        expect(s[:pill_class]).to include("bg-success")
      end

      it "uses warning pill for overall between 50 and 80" do
        create_healthy_clarity_item(teammate: report, entity_type: "Position", entity_id: 1, name: "Engineer")
        EngagementHealthStatus.create!(
          teammate: report,
          organization: company,
          level: "item",
          category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          entity_type: "Assignment",
          entity_id: 2,
          status: EngagementHealth::WARNING,
          inputs: { "name" => "Support" },
          computed_at: Time.current
        )

        s = described_class.new(manager_teammate: manager, organization: company).summary
        expect(s[:overall_pct]).to eq(50.0)
        expect(s[:pill_class]).to include("bg-warning")
      end
    end
  end
end
