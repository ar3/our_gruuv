require 'rails_helper'

RSpec.describe 'Organizations::EligibilityRequirements', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }

  before do
    teammate
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/eligibility_requirements' do
    it 'renders the eligibility requirements index' do
      get organization_eligibility_requirements_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Eligibility Requirements')
    end
  end

  describe 'GET /organizations/:organization_id/eligibility_requirements/:id' do
    before do
      position.update!(
        eligibility_requirements_explicit: {
          "mileage_requirements" => {
            "minimum_mileage_points" => 0
          }
        }
      )
    end

    it 'renders eligibility requirements for the selected teammate and position' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      report = controller.instance_variable_get(:@eligibility_report)
      expect(report).to be_present
      expect(report[:position]).to eq(position)
      expect(report[:teammate]).to eq(teammate)
    end
  end
end
