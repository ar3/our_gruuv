require 'rails_helper'

RSpec.describe 'Organizations::ValueBilling', type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/value_billing' do
    it 'returns http success' do
      get organization_value_billing_path(organization)
      expect(response).to have_http_status(:success)
    end

    it 'renders the value and billing page content with charts' do
      allow_any_instance_of(OrganizationPolicy).to receive(:check_ins_health?).and_return(true)

      get organization_value_billing_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Value / Billing')
      expect(response.body).to include('Beta')
      expect(response.body).to include('Clarity leads to both personal and team growth.')
      expect(response.body).to include('OG helped')
      expect(response.body).to include('Which is valued at')
      expect(response.body).to include('OGO Stories Captured')
      expect(response.body).to include('Clarity Check-ins Completed')
      expect(response.body).to include('Demonstrated Abilities Recognized')
      expect(response.body).to include('Goals Progressed')
      expect(response.body).to include('How value is calculated')
      expect(response.body).to include('data-bs-toggle="tooltip"')
      expect(response.body).to include('Total value attained by week')
      expect(response.body).to include('Last 90 Days')
      expect(response.body).to include('Last 90 days')
      expect(response.body).to include('Custom')
      expect(response.body).to include('value-billing-total-chart')
      expect(response.body).to include('value-billing-milestones-chart')
      expect(response.body).to include('value-billing-observees-chart')
      expect(response.body).to include('value-billing-check-ins-chart')
      expect(response.body).to include('value-billing-goal-check-ins-chart')
      expect(response.body).to include('OG Consultations')
      expect(response.body).to include('value-billing-consultations-chart')
      expect(response.body).to include('Every completed Consult OG consultation is worth $1.00')
      expect(response.body).to include(organization_insights_observations_path(organization, timeframe: '90_days'))
      expect(response.body).to include(organization_insights_check_ins_progress_path(organization, timeframe: '90_days'))
      expect(response.body).to include(organization_insights_abilities_path(organization, timeframe: '90_days'))
      expect(response.body).to include(organization_insights_goals_path(organization, timeframe: '90_days'))
      expect(response.body).to include(organization_insights_og_consultations_path(organization, timeframe: '90_days'))
      expect(response.body).to include('bi-bar-chart-line')
      expect(response.body).to include('More detailed charts')
    end

    it 'accepts timeframe param like Insights' do
      get organization_value_billing_path(organization, timeframe: 'year')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Last Year')
    end

    it 'shows per-employee value or no-teammates message when there are no active teammates' do
      get organization_value_billing_path(organization)
      expect(response.body).to match(/weekly clarity value per active teammate|No active teammates/)
    end

    it 'counts multiple completed OG consultations' do
      teammate = create(:company_teammate, :assigned_employee, organization: organization)
      ability = create(:ability, company: organization)

      2.times do
        create_ability_clarity_consultation!(
          ability: ability,
          status: 'completed',
          triggered_by_teammate: teammate,
          completed_at: Time.current
        )
      end

      get organization_value_billing_path(organization, timeframe: 'year')

      expect(response.body).to include('2 completed Consult OG consultations')
      expect(response.body).to include('Which is valued at $2.00')
    end

    it 'counts completed billable consultations across mixed kinds' do
      teammate = create(:company_teammate, :assigned_employee, organization: organization)
      ability = create(:ability, company: organization)
      assignment = create(:assignment, company: organization)
      transcript = create(:possible_observation_transcript, organization: organization)
      slack_search = create(:possible_observation_slack_search, organization: organization)
      completed_at = Time.current

      create_ability_clarity_consultation!(
        ability: ability,
        status: 'completed',
        triggered_by_teammate: teammate,
        completed_at: completed_at
      )
      create_assignment_clarity_consultation!(
        assignment: assignment,
        status: 'completed',
        triggered_by_teammate: teammate,
        completed_at: completed_at
      )
      create_ogo_search_consultation!(
        subject: transcript,
        kind: OgConsultation::KIND_OGO_SEARCH_TRANSCRIPT,
        organization: organization,
        status: 'completed',
        triggered_by_teammate: teammate,
        completed_at: completed_at,
        items_count: 2
      )
      create_ogo_search_consultation!(
        subject: slack_search,
        kind: OgConsultation::KIND_OGO_SEARCH_SLACK,
        organization: organization,
        status: 'completed',
        triggered_by_teammate: teammate,
        completed_at: completed_at,
        items_count: 1
      )
      create_ability_clarity_consultation!(
        ability: ability,
        status: 'failed',
        triggered_by_teammate: teammate,
        completed_at: completed_at
      )
      create_ability_clarity_consultation!(
        ability: ability,
        status: 'completed',
        billable: false,
        triggered_by_teammate: teammate,
        completed_at: completed_at
      )

      get organization_value_billing_path(organization, timeframe: 'year')

      expect(response.body).to include('4 completed Consult OG consultations')
      expect(response.body).to include('Which is valued at $4.00')
    end
  end
end
