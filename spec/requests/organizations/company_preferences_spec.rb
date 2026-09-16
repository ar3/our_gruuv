require 'rails_helper'

RSpec.describe 'Organizations::CompanyPreferences', type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, :company, name: 'Acme Co') }
  let!(:teammate) do
    create(:company_teammate,
           person: person,
           organization: organization,
           can_customize_company: true,
           first_employed_at: 1.month.ago,
           last_terminated_at: nil)
  end

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/company_preference/edit' do
    it 'returns success and shows company preferences' do
      get edit_organization_company_preference_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Acme Co Preferences')
    end

    it 'breadcrumbs to company preferences without an Observations parent' do
      get edit_organization_company_preference_path(organization)
      expect(response).to have_http_status(:success)
      breadcrumb = CGI.unescapeHTML(response.body[%r{page-context-nav__breadcrumb.*?</nav>}m].to_s)
      expect(breadcrumb).to include('Acme Co preferences')
      expect(breadcrumb).not_to include('>Observations<')
      expect(breadcrumb).not_to match(/href="#{Regexp.escape(organization_observations_path(organization))}"/)
    end
  end
end
