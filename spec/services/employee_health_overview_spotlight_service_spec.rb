# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmployeeHealthOverviewSpotlightService do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:direct_report) { create(:person) }
  let!(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization, first_employed_at: 1.month.ago) }
  let!(:direct_report_teammate) { CompanyTeammate.create!(person: direct_report, organization: organization, first_employed_at: 1.month.ago) }

  before do
    create(:employment_tenure, teammate: direct_report_teammate, company: organization, manager_teammate: manager_teammate, ended_at: nil)
  end

  subject(:service) do
    described_class.new(
      organization: organization,
      current_person: manager,
      current_company_teammate: manager_teammate,
      manage_employment: false,
      manager_teammate_id: manager_teammate.id
    )
  end

  describe "#stats" do
    it "returns manager filter scoped to direct reports" do
      expect(service.stats[:manager_filter]).to eq("my_direct_employees")
    end

    it "includes check-ins, goals, and observations sections" do
      stats = service.stats
      expect(stats).to include(:check_ins, :goals, :observations)
      expect(stats[:check_ins][:stats]).to include(:total_employees, :healthy_count, :ok_count, :concerning_count)
      expect(stats[:goals][:stats]).to include(:total_employees, :healthy_count, :ok_count, :concerning_count)
      expect(stats[:observations][:stats]).to include(:total_employees, :healthy_count, :ok_count, :concerning_count)
    end

    context "when viewing another manager's employees" do
      let(:other_manager) { create(:person) }
      let!(:other_manager_teammate) { CompanyTeammate.create!(person: other_manager, organization: organization, first_employed_at: 1.month.ago) }

      subject(:service) do
        described_class.new(
          organization: organization,
          current_person: manager,
          current_company_teammate: manager_teammate,
          manage_employment: true,
          manager_teammate_id: other_manager_teammate.id
        )
      end

      it "uses CompanyTeammate filter format" do
        expect(service.stats[:manager_filter]).to eq("CompanyTeammate_#{other_manager_teammate.id}")
      end
    end

    it "passes impersonating_teammate into the organization policy pundit user" do
      impersonating = manager_teammate
      service = described_class.new(
        organization: organization,
        current_person: manager,
        current_company_teammate: manager_teammate,
        manage_employment: false,
        manager_teammate_id: manager_teammate.id,
        impersonating_teammate: impersonating
      )

      policy = service.send(:organization_policy)
      expect(policy.pundit_user.impersonating_teammate).to eq(impersonating)
    end
  end
end
