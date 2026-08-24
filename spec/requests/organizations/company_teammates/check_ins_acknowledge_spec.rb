# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Check-in acknowledgement", type: :request do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:manager) { create(:person) }
  let!(:employee_teammate) do
    create(:company_teammate, person: employee, organization: organization, first_employed_at: 1.year.ago)
  end
  let!(:manager_teammate) do
    create(:company_teammate, person: manager, organization: organization, can_manage_employment: true, first_employed_at: 1.year.ago)
  end
  let!(:employment_tenure) do
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, manager: manager)
  end
  let!(:manager_employment) do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago)
  end
  let(:assignment) { create(:assignment, company: organization) }
  let(:assignment_two) { create(:assignment, company: organization, title: "Second") }
  let!(:assignment_check_in) do
    create(:assignment_check_in, :officially_completed,
           teammate: employee_teammate,
           assignment: assignment,
           official_check_in_completed_at: 1.day.ago)
  end
  let!(:assignment_check_in_two) do
    create(:assignment_check_in, :officially_completed,
           teammate: employee_teammate,
           assignment: assignment_two,
           official_check_in_completed_at: 1.day.ago)
  end

  describe "GET acknowledge" do
    it "shows pending check-ins with rating columns and bulk controls" do
      sign_in_as_teammate_for_request(employee, organization)

      get acknowledge_organization_company_teammate_check_ins_path(organization, employee_teammate)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(assignment.title)
      expect(response.body).to include("Acknowledge and Agree")
      expect(response.body).to include("Leave Unacknowledged")
      expect(response.body).to include("Set all to Agree")
      expect(response.body).to include("Save All")
      expect(response.body).to include("Acknowledge Check-ins")
      expect(response.body).not_to include("Try the new acknowledgement experience")
      expect(response.body).to include("data-bs-toggle=\"popover\"")
    end

    it "allows managers with audit access to view without submit controls" do
      sign_in_as_teammate_for_request(manager, organization)

      get acknowledge_organization_company_teammate_check_ins_path(organization, employee_teammate)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(assignment.title)
      expect(response.body).to include("Awaiting")
      expect(response.body).not_to include('id="bulk-acknowledge-form"')
      expect(response.body).not_to include('id="set-all-ack-agree"')
      expect(response.body).not_to include('value="Save All"')
    end
  end

  describe "PATCH update_acknowledgement" do
    it "bulk-saves agree/disagree and skips leave_unacknowledged" do
      sign_in_as_teammate_for_request(employee, organization)

      patch update_acknowledgement_organization_company_teammate_check_ins_path(organization, employee_teammate),
            params: {
              acknowledgements: {
                assignment: {
                  assignment_check_in.id.to_s => {
                    employee_acknowledgement: "agree",
                    employee_acknowledgement_notes: "Fair"
                  },
                  assignment_check_in_two.id.to_s => {
                    employee_acknowledgement: "leave_unacknowledged"
                  }
                }
              }
            }

      expect(response).to redirect_to(acknowledge_organization_company_teammate_check_ins_path(organization, employee_teammate))
      assignment_check_in.reload
      expect(assignment_check_in.employee_acknowledged_at).to be_present
      expect(assignment_check_in).to be_employee_acknowledgement_agree
      expect(assignment_check_in.employee_acknowledgement_notes).to eq("Fair")
      expect(assignment_check_in_two.reload.employee_acknowledged_at).to be_nil
    end

    it "does not let a manager submit acknowledgement" do
      sign_in_as_teammate_for_request(manager, organization)

      patch update_acknowledgement_organization_company_teammate_check_ins_path(organization, employee_teammate),
            params: {
              acknowledgements: {
                assignment: {
                  assignment_check_in.id.to_s => { employee_acknowledgement: "disagree" }
                }
              }
            }

      expect(response).to redirect_to(acknowledge_organization_company_teammate_check_ins_path(organization, employee_teammate))
      expect(assignment_check_in.reload.employee_acknowledged_at).to be_nil
    end

    it "does not change snapshot acknowledgement" do
      snapshot = create(:maap_snapshot,
                        employee_company_teammate: employee_teammate,
                        creator_company_teammate: manager_teammate,
                        company: organization,
                        change_type: "assignment_management",
                        reason: "Test",
                        effective_date: Time.current,
                        employee_acknowledged_at: nil)
      assignment_check_in.update!(maap_snapshot: snapshot)

      sign_in_as_teammate_for_request(employee, organization)

      patch update_acknowledgement_organization_company_teammate_check_ins_path(organization, employee_teammate),
            params: {
              acknowledgements: {
                assignment: {
                  assignment_check_in.id.to_s => { employee_acknowledgement: "agree" }
                }
              }
            }

      expect(snapshot.reload.employee_acknowledged_at).to be_nil
    end
  end

  describe "GET audit page link" do
    it "points people from audit to the acknowledgement page" do
      sign_in_as_teammate_for_request(employee, organization)

      get audit_organization_employee_path(organization, employee_teammate)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Go to check-in acknowledgement")
      expect(response.body).to include(acknowledge_organization_company_teammate_check_ins_path(organization, employee_teammate))
      expect(response.body).not_to include("Try the new acknowledgement experience")
    end
  end
end
