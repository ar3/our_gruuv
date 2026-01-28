require 'rails_helper'

RSpec.describe 'Organizations::Employees#acknowledge_snapshots', type: :request do
  # When the employee clicks acknowledge, we must redirect using the teammate (not the person)
  # so the user lands on the correct audit URL. Using person can send them to the wrong place
  # because audit routes expect teammate id in modern usage.

  let(:organization) { create(:organization, :company) }
  # Create another person first so employee and employee_teammate get different ids (person.id != teammate.id),
  # which is the normal case and is when the redirect-to-person bug sends the user to the wrong place.
  let!(:_other_person) { create(:person) }
  let(:employee) { create(:person) }
  let!(:employee_teammate) { create(:company_teammate, person: employee, organization: organization, first_employed_at: 1.year.ago) }
  let!(:employee_employment) { create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago) }
  let(:maap_manager) { create(:person) }
  let!(:maap_manager_teammate) { create(:company_teammate, person: maap_manager, organization: organization, can_manage_maap: true, can_manage_employment: true, first_employed_at: 1.year.ago) }
  let!(:maap_manager_employment) { create(:employment_tenure, teammate: maap_manager_teammate, company: organization, started_at: 1.year.ago) }

  it 'redirects to the audit page using the teammate (not the person) so the user lands in the right place' do
    pending_snapshot = create(:maap_snapshot,
      employee_company_teammate: employee_teammate,
      creator_company_teammate: maap_manager_teammate,
      company: organization,
      change_type: 'assignment_management',
      reason: 'Snapshot to acknowledge',
      effective_date: 1.day.ago,
      employee_acknowledged_at: nil
    )

    sign_in_as_teammate_for_request(employee, organization)

    patch acknowledge_snapshots_organization_employee_path(organization, employee),
          params: { snapshot_ids: [pending_snapshot.id] }

    # Must redirect using teammate (not person) so the user lands on the correct audit URL.
    # When person.id != teammate.id, redirecting with person sends them to the wrong place.
    expect(response).to redirect_to(audit_organization_employee_path(organization, employee_teammate))
  end
end
