require 'rails_helper'

RSpec.describe 'Organization Dashboard Redirect', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { CompanyTeammate.create!(person: person, organization: organization, can_manage_employment: true) }

  before do
    sign_in_as(person, organization)
  end

  describe 'Dashboard redirects to about_me' do
    it 'redirects to about_me page' do
      visit dashboard_organization_path(organization)

      expect(current_path).to eq(about_me_organization_company_teammate_path(organization, teammate))
      expect(page).to have_content("About #{person.casual_name}")
    end

    it 'redirects correctly when accessed via URL' do
      visit dashboard_organization_path(organization)

      # Should be redirected to about_me
      expect(page).to have_current_path(about_me_organization_company_teammate_path(organization, teammate))
    end
  end
end
