# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organization position eligibility defaults', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:company_teammate, person: person, organization: organization, can_manage_maap: true) }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/position_eligibility_defaults' do
    it 'renders summary for minors 1–3' do
      get organization_position_eligibility_defaults_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Position eligibility defaults')
      expect(response.body).to include('Positions *.1')
      expect(response.body).to include('Positions *.3')
    end
  end

  describe 'PATCH /organizations/:organization_id/position_eligibility_defaults/minors/:minor' do
    it 'find-or-creates a requirement and sets the organization minor FK' do
      expect do
        patch update_minor_organization_position_eligibility_defaults_path(organization, minor: 1), params: {
          eligibility_requirements: {
            mileage_requirements: {
              threshold_type: 'absolute',
              minimum_mileage_points: '42'
            }
          }
        }
      end.to change(PositionEligibilityRequirement, :count).by_at_least(1)

      expect(response).to redirect_to(organization_position_eligibility_defaults_path(organization))

      organization.reload
      expect(organization.minor_1_position_eligibility_requirement.mileage_threshold_type).to eq('absolute')
      expect(organization.minor_1_position_eligibility_requirement.mileage_threshold_value).to eq(42)
    end

    it 'records a PaperTrail version when the minor FK changes' do
      expect do
        patch update_minor_organization_position_eligibility_defaults_path(organization, minor: 1), params: {
          eligibility_requirements: {
            mileage_requirements: {
              threshold_type: 'absolute',
              minimum_mileage_points: '91'
            }
          }
        }
      end.to change { organization.reload.versions.count }.by(1)
    end

    it 'redirects when teammate cannot manage MAAP' do
      teammate.update!(can_manage_maap: false)

      patch update_minor_organization_position_eligibility_defaults_path(organization, minor: 2), params: {
        eligibility_requirements: {}
      }

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end
  end
end
