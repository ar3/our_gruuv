# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Teammates::CheckInPeriodBriefConsults", type: :request do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company) }
  let(:employee_person) { create(:person) }
  let(:manager_person) { create(:person) }
  let!(:employee_teammate) { create(:company_teammate, :assigned_employee, person: employee_person, organization: organization) }
  let!(:manager_teammate) do
    create(:company_teammate, :assigned_employee, person: manager_person, organization: organization, can_manage_employment: true)
  end
  let(:assignment) { create(:assignment, company: organization) }
  let!(:open_check_in) do
    create(
      :assignment_check_in,
      teammate: employee_teammate,
      assignment: assignment,
      check_in_started_on: Date.current,
      official_check_in_completed_at: nil
    )
  end

  before do
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    EmploymentTenure.find_by!(company_teammate: employee_teammate, company: organization)
                    .update!(manager_teammate: manager_teammate)
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 60.days.ago)
    PaperTrail.enabled = false
  end

  after { PaperTrail.enabled = true }

  describe "POST create" do
    it "creates a billable consultation and enqueues the job for the manager" do
      sign_in_as_teammate_for_request(manager_person, organization)

      expect do
        post organization_teammate_check_in_period_brief_consult_path(organization, employee_teammate),
             params: { check_in_kind: "assignment", check_in_id: open_check_in.id },
             as: :json
      end.to have_enqueued_job(CheckInPeriodBriefJob)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["ok"]).to eq(true)
      expect(json["status"]).to eq("pending")
      expect(json["polling"]).to eq(true)
      run = open_check_in.reload.latest_period_brief_consultation
      expect(run).to be_present
      expect(run.kind).to eq(OgConsultation::KIND_CHECK_IN_PERIOD_BRIEF)
      expect(run.billable).to be(true)
      expect(run.status).to eq("pending")
    end

    it "reuses an in-flight consultation for the same viewer" do
      sign_in_as_teammate_for_request(manager_person, organization)
      inflight = create_check_in_period_brief_consultation!(
        check_in: open_check_in,
        status: "processing",
        triggered_by_teammate: manager_teammate
      )

      expect do
        post organization_teammate_check_in_period_brief_consult_path(organization, employee_teammate),
             params: { check_in_kind: "assignment", check_in_id: open_check_in.id },
             as: :json
      end.not_to have_enqueued_job(CheckInPeriodBriefJob)

      expect(open_check_in.reload.latest_period_brief_consultation_for(manager_teammate)).to eq(inflight)
      json = JSON.parse(response.body)
      expect(json["ok"]).to eq(true)
      expect(json["id"]).to eq(inflight.id)
    end
  end

  describe "GET show status" do
    it "returns status payload JSON" do
      sign_in_as_teammate_for_request(manager_person, organization)
      create_check_in_period_brief_consultation!(
        check_in: open_check_in,
        status: "processing",
        triggered_by_teammate: manager_teammate
      )

      get organization_teammate_check_in_period_brief_consult_path(
        organization,
        employee_teammate,
        check_in_kind: "assignment",
        check_in_id: open_check_in.id,
        format: :json
      )

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("processing")
      expect(json["polling"]).to eq(true)
    end

    it "includes the brief text when completed" do
      sign_in_as_teammate_for_request(manager_person, organization)
      create_check_in_period_brief_consultation!(
        check_in: open_check_in,
        status: "completed",
        triggered_by_teammate: manager_teammate,
        output_text: "OG's brief of Pat and Assignment Demo between Jan 1, 2026 - now Nov 2, 2026:\n\nShipped demos."
      )

      get organization_teammate_check_in_period_brief_consult_path(
        organization,
        employee_teammate,
        check_in_kind: "assignment",
        check_in_id: open_check_in.id,
        format: :json
      )

      json = JSON.parse(response.body)
      expect(json["status"]).to eq("completed")
      expect(json["polling"]).to eq(false)
      expect(json["output_text"]).to include("Shipped demos.")
      expect(json["completed_at_display"]).to be_present
    end
  end
end
