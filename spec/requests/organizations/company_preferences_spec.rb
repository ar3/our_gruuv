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
    it 'returns success and shows company preferences grouped by section' do
      get edit_organization_company_preference_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Acme Co Preferences')
      expect(response.body).to include('Terminology &amp; labels').or include('Terminology & labels')
      expect(response.body).to include('Clarity check-ins')
      expect(response.body).to include('Required Clarity windows')
      expect(response.body).to include('Job description defaults')
      expect(response.body).to include('Branding &amp; notifications').or include('Branding & notifications')
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

  describe 'PATCH /organizations/:organization_id/company_preference' do
    let(:healthy_key) { EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS_KEY }
    let(:needs_key) { EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS_KEY }

    it 'saves Required Clarity windows and enqueues EH refresh' do
      expect(EngagementHealthLiveCacheBackfillJob).to receive(:perform_later).with(organization.id, [teammate.id])

      patch organization_company_preference_path(organization), params: {
        preferences: {
          healthy_key => '45',
          needs_key => '100'
        }
      }

      expect(response).to redirect_to(edit_organization_company_preference_path(organization))
      expect(EngagementHealth::Thresholds.required_clarity_healthy_within_days(organization.reload)).to eq(45)
      expect(EngagementHealth::Thresholds.required_clarity_needs_attention_at_days(organization)).to eq(100)
    end

    it 'rejects Healthy that is not greater than the early window' do
      patch organization_company_preference_path(organization), params: {
        preferences: {
          healthy_key => '30',
          needs_key => '90'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('30 &lt; Healthy &lt; Needs Attention').or include('30 < Healthy < Needs Attention')
      expect(organization.company_label_preferences.find_by(label_key: healthy_key)).to be_nil
    end

    it 'rejects Needs Attention that is not greater than Healthy' do
      patch organization_company_preference_path(organization), params: {
        preferences: {
          healthy_key => '60',
          needs_key => '60'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(organization.company_label_preferences.find_by(label_key: needs_key)).to be_nil
    end
  end
end
