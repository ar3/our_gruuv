# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Position assignment ratings research', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:assignment) { create(:assignment, company: organization, title: 'Core Delivery') }

  let!(:manager_teammate) { create(:company_teammate, person: manager, organization: organization, can_manage_employment: true) }
  let!(:teammate) { create(:company_teammate, person: employee, organization: organization) }

  let!(:employment_tenure) do
    create(:employment_tenure,
      teammate: teammate,
      company: organization,
      manager: manager,
      position: position,
      started_at: 1.month.ago)
  end

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    teammate.update!(first_employed_at: 1.month.ago)
    create(
      :assignment_tenure,
      teammate: teammate,
      assignment: assignment,
      anticipated_energy_percentage: 100,
      ended_at: nil
    )
    sign_in_as_teammate_for_request(manager, organization)
  end

  describe 'GET #position_assignment_ratings_research' do
    it 'returns the turbo frame accordion for finalization context' do
      get position_assignment_ratings_research_organization_company_teammate_path(
        organization,
        teammate,
        context: 'finalization',
        chart_id_prefix: 'finalization-experiences'
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include("position_assignment_ratings_research_#{teammate.id}")
      expect(response.body).to include('Assignment ratings research')
      expect(response.body).to include('uncheck the Position row')
      expect(response.body).to include('finalization-experiences-inflight-rating-pie-chart')
    end
  end

  describe 'bulk check-ins show' do
    before do
      create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure)
    end

    it 'renders the research accordion above Position/Overall' do
      get organization_company_teammate_check_ins_path(organization, teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Assignment ratings research')
      expect(response.body).to include('bulk-check-in-experiences-energy-pie-chart')
      expect(response.body).to include('click here to refresh')

      body = response.body
      expect(body.index('Assignment ratings research')).to be < body.index('Position/Overall')
    end
  end

  describe 'finalization show' do
    it 'renders the research accordion with finalization freshness copy' do
      get organization_company_teammate_finalization_path(organization, teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Assignment ratings research')
      expect(response.body).to include('uncheck the Position row')
      expect(response.body).to include('finalization-experiences-rating-pie-chart')
    end
  end
end
