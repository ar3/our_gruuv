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

    it 'renders aspirational values section with a table' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Aspirational Values')
      expect(response.body).to include('<table')
      expect(response.body).to include('Requirement')
      expect(response.body).to include('Position Requirement')
      expect(response.body).to include('Teammate Status')
    end

    it 'renders 12 status blocks per aspirational value row when aspirations exist' do
      create(:aspiration, company: organization, name: 'Integrity', sort_order: 0)

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Integrity')
      # Each block has inline style "width: 12px; height: 12px; min-width: 12px;"
      block_count = response.body.scan('12px; height: 12px').size
      expect(block_count).to eq(12), "Expected 12 status blocks for the one aspiration row, got #{block_count}"
    end

    it 'shows green block for month with finalized check-in rated exceeding' do
      aspiration = create(:aspiration, company: organization, name: 'Excellence', sort_order: 0)
      target_month = 3.months.ago.beginning_of_month.to_date
      create(:aspiration_check_in, :finalized,
        teammate: teammate,
        aspiration: aspiration,
        check_in_started_on: target_month,
        official_rating: 'exceeding'
      )

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Excellence')
      # That month's block should be green (bg-success)
      expect(response.body).to include('bg-success')
    end
  end
end
