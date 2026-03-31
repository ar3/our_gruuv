# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Department position eligibility defaults', type: :request do
  let(:organization) { create(:organization) }
  let(:department) { create(:department, company: organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:company_teammate, person: person, organization: organization, can_manage_maap: true) }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/departments/:department_id/position_eligibility_defaults' do
    it 'renders summary for minors 1–3' do
      get organization_department_position_eligibility_defaults_path(organization, department)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Position eligibility defaults')
      expect(response.body).to include('Minor 1')
    end
  end

  describe 'PATCH .../position_eligibility_defaults/minors/:minor' do
    it 'updates department minor 3 eligibility default' do
      patch update_minor_organization_department_position_eligibility_defaults_path(organization, department, minor: 3), params: {
        eligibility_requirements: {
          mileage_requirements: {
            threshold_type: 'absolute',
            minimum_mileage_points: '55'
          }
        }
      }

      expect(response).to redirect_to(organization_department_position_eligibility_defaults_path(organization, department))

      department.reload
      expect(department.minor_3_position_eligibility_requirement.mileage_threshold_value).to eq(55)
    end

    it 'creates a PaperTrail version for the department when the FK changes' do
      expect do
        patch update_minor_organization_department_position_eligibility_defaults_path(organization, department, minor: 2), params: {
          eligibility_requirements: {
            mileage_requirements: {
              threshold_type: 'absolute',
              minimum_mileage_points: '88'
            }
          }
        }
      end.to change { department.reload.versions.count }.by(1)
    end

    it 'redirects when teammate cannot manage MAAP' do
      teammate.update!(can_manage_maap: false)

      patch update_minor_organization_department_position_eligibility_defaults_path(organization, department, minor: 1), params: {
        eligibility_requirements: {}
      }

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end
  end
end
