require 'rails_helper'

RSpec.describe 'Organization Dashboard Redirect', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { CompanyTeammate.create!(person: person, organization: organization, can_manage_employment: true) }

  before do
    sign_in_as(person, organization)
  end

  describe 'Dashboard redirects to preferred start page' do
    it 'redirects to OG Academy by default' do
      visit dashboard_organization_path(organization)

      expect(current_path).to eq(organization_og_academy_path(organization))
      expect(page).to have_content('OG Academy')
    end

    it 'redirects to Start Here when configured as start page' do
      UserPreference.for_person(person).update_preference("start_page_#{organization.id}", 'start_here')

      visit dashboard_organization_path(organization)

      expect(page).to have_current_path(organization_start_here_path(organization))
    end
  end
end
