# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Company teammate True JD print route', type: :request do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person, preferred_name: 'Sam C.', first_name: 'Samantha', last_name: 'Cartwright') }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:peer) { create(:person) }
  let(:peer_teammate) { create(:teammate, person: peer, organization: organization) }

  before do
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: peer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    employee_teammate.update!(first_employed_at: 1.year.ago)
    peer_teammate.update!(first_employed_at: 1.year.ago)
  end

  describe 'GET /organizations/:organization_id/company_teammates/:id/true_jd_print' do
    it 'redirects peers to the combined print/sign page' do
      sign_in_as_teammate_for_request(peer, organization)

      get true_jd_print_organization_company_teammate_path(organization, employee_teammate)

      expect(response).to redirect_to(
        organization_company_teammate_job_description_acknowledgements_path(organization, employee_teammate)
      )
    end

    context 'when the viewer is from another organization' do
      let(:other_organization) { create(:organization) }
      let(:outsider) { create(:person) }
      let(:outsider_teammate) { create(:teammate, person: outsider, organization: other_organization) }

      before do
        create(:employment_tenure, teammate: outsider_teammate, company: other_organization, started_at: 1.year.ago, ended_at: nil)
        outsider_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(outsider, other_organization)
      end

      it 'denies access' do
        get true_jd_print_organization_company_teammate_path(organization, employee_teammate)
        expect(response).not_to have_http_status(:success)
        expect(response).not_to redirect_to(
          organization_company_teammate_job_description_acknowledgements_path(organization, employee_teammate)
        )
      end
    end
  end
end
