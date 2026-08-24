# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Employees#acknowledge_snapshots", type: :request do
  let(:organization) { create(:organization) }
  let!(:_other_person) { create(:person) }
  let(:employee) { create(:person) }
  let!(:employee_teammate) { create(:company_teammate, person: employee, organization: organization, first_employed_at: 1.year.ago) }
  let!(:employee_employment) { create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago) }
  let(:maap_manager) { create(:person) }
  let!(:maap_manager_teammate) { create(:company_teammate, person: maap_manager, organization: organization, can_manage_maap: true, can_manage_employment: true, first_employed_at: 1.year.ago) }
  let!(:maap_manager_employment) { create(:employment_tenure, teammate: maap_manager_teammate, company: organization, started_at: 1.year.ago) }

  it "hard-disables snapshot acknowledgement and redirects to the check-in acknowledge page" do
    pending_snapshot = create(:maap_snapshot,
      employee_company_teammate: employee_teammate,
      creator_company_teammate: maap_manager_teammate,
      company: organization,
      change_type: "assignment_management",
      reason: "Snapshot to acknowledge",
      effective_date: 1.day.ago,
      employee_acknowledged_at: nil
    )

    sign_in_as_teammate_for_request(employee, organization)

    patch acknowledge_snapshots_organization_employee_path(organization, employee),
          params: { snapshot_ids: [pending_snapshot.id] }

    expect(response).to redirect_to(acknowledge_organization_company_teammate_check_ins_path(organization, employee_teammate))
    expect(flash[:alert]).to include("moved")
    expect(pending_snapshot.reload.employee_acknowledged_at).to be_nil
  end
end
