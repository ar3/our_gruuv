# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::BackfillAcknowledgementsFromSnapshots do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:teammate) { create(:company_teammate, person: employee, organization: organization, first_employed_at: 1.year.ago) }
  let!(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago) }
  let(:manager) { create(:person) }
  let!(:manager_teammate) { create(:company_teammate, person: manager, organization: organization, first_employed_at: 1.year.ago) }
  let(:assignment) { create(:assignment, company: organization) }
  let!(:snapshot) do
    create(:maap_snapshot,
           employee_company_teammate: teammate,
           creator_company_teammate: manager_teammate,
           company: organization,
           effective_date: 1.day.ago,
           employee_acknowledged_at: 1.day.ago,
           employee_acknowledgement_request_info: { "request_source" => "audit_page", "ip_address" => "1.2.3.4" })
  end
  let!(:check_in) do
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: assignment,
           maap_snapshot: snapshot,
           official_check_in_completed_at: 2.days.ago)
  end

  it "backfills closed check-ins on acknowledged snapshots as agree" do
    result = described_class.call(dry_run: false)

    expect(result).to be_ok
    expect(result.value[:updated]).to eq(1)
    check_in.reload
    expect(check_in).to be_employee_acknowledgement_agree
    expect(check_in.employee_acknowledged_at).to be_within(1.second).of(snapshot.employee_acknowledged_at)
    expect(check_in.employee_acknowledgement_request_info["request_source"]).to eq("migrated_from_snapshot")
    expect(check_in.employee_acknowledgement_request_info["snapshot_id"]).to eq(snapshot.id)
    expect(check_in.employee_acknowledgement_request_info["ip_address"]).to eq("1.2.3.4")
  end

  it "is idempotent on re-run" do
    described_class.call(dry_run: false)
    result = described_class.call(dry_run: false)
    expect(result.value[:updated]).to eq(0)
    expect(result.value[:scanned]).to eq(0)
  end
end
