require 'rails_helper'

RSpec.describe 'Get Shit Done Dashboard', type: :system do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { CompanyTeammate.find_or_create_by!(person: person, organization: company) }

  before do
    sign_in_as(person, company)
  end

  # Dashboard content (pending moments, snapshots, drafts, goals, badge) is covered by
  # spec/requests/organizations/get_shit_done_spec.rb. This keeps one minimal UX smoke.
  describe 'visit get shit done page' do
    it 'visits get shit done page and sees default title' do
      visit organization_get_shit_done_path(company)

      expect(page).to have_content('Get Shit Done')
    end

    it 'shows custom label when company preference is set' do
      create(:company_label_preference, company: company, label_key: 'get_shit_done', label_value: 'Action Items')
      visit organization_get_shit_done_path(company)

      expect(page).to have_content('Action Items')
    end
  end
end
