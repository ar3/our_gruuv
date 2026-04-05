# frozen_string_literal: true

require "rails_helper"

RSpec.describe MyEmployeesDashboardService do
  let(:company) { create(:organization, :company) }
  let(:manager) { create(:company_teammate, organization: company) }
  let(:report) { create(:company_teammate, organization: company) }

  def maxed_check_in_payload
    t = Time.current.iso8601
    {
      "position" => {
        "category" => "neon_green",
        "employee_completed_at" => t,
        "manager_completed_at" => t,
        "official_check_in_completed_at" => t,
        "acknowledged_at" => t
      },
      "assignments" => [
        {
          "item_id" => 1,
          "category" => "neon_green",
          "employee_completed_at" => t,
          "manager_completed_at" => t,
          "official_check_in_completed_at" => t,
          "acknowledged_at" => t
        }
      ],
      "aspirations" => [
        {
          "item_id" => 1,
          "category" => "neon_green",
          "employee_completed_at" => t,
          "manager_completed_at" => t,
          "official_check_in_completed_at" => t,
          "acknowledged_at" => t
        }
      ],
      "milestones" => { "total_required" => 0, "earned_count" => 0 }
    }
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

      it "counts direct reports and averages 0% clarity without cache" do
        s = described_class.summary(manager_teammate: manager, organization: company)
        expect(s[:direct_report_count]).to eq(1)
        expect(s[:crystal_clear_count]).to eq(0)
        expect(s[:overall_pct]).to eq(0.0)
        expect(s[:pill_class]).to include("bg-danger")
      end

      it "counts crystal clear and success pill when report cache is fully maxed" do
        create(:check_in_health_cache, teammate: report, organization: company, payload: maxed_check_in_payload)
        s = described_class.summary(manager_teammate: manager, organization: company)
        expect(s[:crystal_clear_count]).to eq(1)
        expect(s[:overall_pct]).to eq(100.0)
        expect(s[:pill_class]).to include("bg-success")
      end

      it "uses warning pill for overall between 50 and 80" do
        allow(CheckInHealthCompletionRate).to receive(:average_completion_rate_per_teammate).and_return(65.0)
        allow(CheckInHealthCompletionRate).to receive(:teammate_fully_clear_on_check_ins?).and_return(false)
        s = described_class.new(manager_teammate: manager, organization: company).summary
        expect(s[:pill_class]).to include("bg-warning")
      end
    end
  end
end
